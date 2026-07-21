#!/usr/bin/env python3
"""Validate the MAPPINGS reference tables.

All tables are TSV. An empty field ("") is treated as NA.

Run:
    python3 MAPPINGS/tests/tables_validation.py

Exit code is 0 when every check passes, 1 otherwise.
"""

import ast
import csv
import math
import sys
from pathlib import Path

MAPPINGS_DIR = Path(__file__).resolve().parent.parent

UNITSFI = MAPPINGS_DIR / "UNITSfi.tsv"
LABFI = MAPPINGS_DIR / "LABfi.tsv"
QUANTITY = MAPPINGS_DIR / "quantity_source_unit_conversion.tsv"
COUNTS = MAPPINGS_DIR / "harmonization_counts.tsv"

# Column names (kept as constants so a rename is a one-line change).
OMOP_ID = "harmonization_omop::OMOP_ID"
OMOP_QUANTITY = "harmonization_omop::OMOP_QUANTITY"
MAPPING_STATUS = "harmonization_omop::MAPPING_STATUS"
COUNTS_UNIT = "harmonization_omop::MEASUREMENT_UNIT"


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def read_tsv(path):
    """Read a TSV into a list of dict rows. '' stays '' (== NA)."""
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def is_na(v):
    return v is None or v == ""


class Report:
    def __init__(self):
        self.failures = 0
        self.warnings = 0
        self.checks = 0

    def _report(self, level, name, offenders, describe, limit):
        self.checks += 1
        if not offenders:
            print(f"  [PASS] {name}")
            return
        print(f"  [{level}] {name} ({len(offenders)} offending)")
        for o in offenders[:limit]:
            print(f"         - {describe(o)}")
        if len(offenders) > limit:
            print(f"         ... and {len(offenders) - limit} more")

    def check(self, name, offenders, describe=lambda o: str(o), limit=10):
        """Hard check: any offender fails the run."""
        if offenders:
            self.failures += 1
        self._report("FAIL", name, offenders, describe, limit)

    def warn(self, name, offenders, describe=lambda o: str(o), limit=10):
        """Soft check: offenders are reported but do not fail the run."""
        if offenders:
            self.warnings += 1
        self._report("WARN", name, offenders, describe, limit)


def find_duplicates(rows, key_fields):
    """Return list of (key, count) for keys appearing more than once."""
    seen = {}
    for r in rows:
        key = tuple(r[k] for k in key_fields)
        seen[key] = seen.get(key, 0) + 1
    return [(k, c) for k, c in seen.items() if c > 1]


def parse_conversion(v):
    """Return float if v is a plain numeric conversion, else None (formula/NA)."""
    if is_na(v):
        return None
    try:
        return float(v)
    except ValueError:
        return None  # formula such as "0.703*X+0"


def valid_prev_format(v):
    """PREV_SOURCE / PREV_INJECTED must be a python-dict literal {str: float}."""
    if is_na(v):
        return False
    try:
        d = ast.literal_eval(v)
    except (ValueError, SyntaxError):
        return False
    if not isinstance(d, dict) or not d:
        return False
    for k, val in d.items():
        if not isinstance(k, str) or not isinstance(val, (int, float)):
            return False
    return True


# --------------------------------------------------------------------------- #
# per-table validations
# --------------------------------------------------------------------------- #
def validate_unitsfi(rep, rows):
    print("\nUNITSfi.tsv")
    cols = ["MEASUREMENT_UNIT", "OMOP_ID", "UNIQUE_FOR_LAB"]

    empties = [(i, c) for i, r in enumerate(rows, 2) for c in cols if is_na(r[c])]
    rep.check("no empty fields in any column", empties,
              lambda o: f"row {o[0]} column {o[1]} empty")

    rep.check("MEASUREMENT_UNIT unique",
              find_duplicates(rows, ["MEASUREMENT_UNIT"]),
              lambda o: f"{o[0][0]!r} x{o[1]}")

    bad_bool = [(i, r["UNIQUE_FOR_LAB"]) for i, r in enumerate(rows, 2)
                if r["UNIQUE_FOR_LAB"] not in ("TRUE", "FALSE")]
    rep.check("UNIQUE_FOR_LAB is boolean (TRUE/FALSE)", bad_bool,
              lambda o: f"row {o[0]}: {o[1]!r}")


def validate_labfi(rep, rows):
    print("\nLABfi.tsv")

    empty_abbr = [i for i, r in enumerate(rows, 2) if is_na(r["TEST_NAME_ABBREVIATION"])]
    rep.check("TEST_NAME_ABBREVIATION not empty", empty_abbr,
              lambda o: f"row {o}")

    allowed_status = {r[MAPPING_STATUS] for r in rows if not is_na(r[MAPPING_STATUS])}
    empty_status = [i for i, r in enumerate(rows, 2) if is_na(r[MAPPING_STATUS])]
    rep.check("MAPPING_STATUS not empty", empty_status, lambda o: f"row {o}")
    bad_status = [(i, r[MAPPING_STATUS]) for i, r in enumerate(rows, 2)
                  if not is_na(r[MAPPING_STATUS]) and r[MAPPING_STATUS] not in allowed_status]
    rep.check(f"MAPPING_STATUS in allowed {sorted(allowed_status)}", bad_status,
              lambda o: f"row {o[0]}: {o[1]!r}")

    rep.check("TEST_NAME_ABBREVIATION + MEASUREMENT_UNIT unique",
              find_duplicates(rows, ["TEST_NAME_ABBREVIATION", "MEASUREMENT_UNIT"]),
              lambda o: f"{o[0]} x{o[1]}")

    # APPROVED rows must carry a real OMOP_ID (not empty, not 0).
    bad_id = [(i, r[OMOP_ID]) for i, r in enumerate(rows, 2)
              if r[MAPPING_STATUS] == "APPROVED" and (is_na(r[OMOP_ID]) or r[OMOP_ID] == "0")]
    rep.check("APPROVED rows have non-empty, non-zero OMOP_ID", bad_id,
              lambda o: f"row {o[0]}: OMOP_ID={o[1]!r}")

    # one OMOP_ID must map to exactly one OMOP_QUANTITY
    id_to_q = {}
    for r in rows:
        oid = r[OMOP_ID]
        if is_na(oid):
            continue
        id_to_q.setdefault(oid, set()).add(r[OMOP_QUANTITY])
    conflict = [(oid, qs) for oid, qs in id_to_q.items() if len(qs) > 1]
    rep.check("OMOP_ID maps to a single OMOP_QUANTITY", conflict,
              lambda o: f"OMOP_ID {o[0]} -> {sorted(o[1])}")


def validate_quantity(rep, rows):
    print("\nquantity_source_unit_conversion.tsv")

    # An empty MEASUREMENT_UNIT / TO_MEASUREMENT_UNIT is a valid unit (qualitative,
    # "no unit"). Only OMOP_QUANTITY and CONVERSION must always be filled.
    must_fill = [OMOP_QUANTITY, "CONVERSION"]
    empties = [(i, c) for i, r in enumerate(rows, 2)
               for c in must_fill if is_na(r[c])]
    rep.check("OMOP_QUANTITY and CONVERSION not empty", empties,
              lambda o: f"row {o[0]} column {o[1]} empty")

    # Formula conversions (e.g. "0.703*X+0") are concept-specific overrides and may
    # coexist with the plain identity row for the same triple, so exclude them here.
    plain = [r for r in rows if parse_conversion(r["CONVERSION"]) is not None]
    rep.check("OMOP_QUANTITY + MEASUREMENT_UNIT + TO_MEASUREMENT_UNIT unique (non-formula)",
              find_duplicates(plain, [OMOP_QUANTITY, "MEASUREMENT_UNIT", "TO_MEASUREMENT_UNIT"]),
              lambda o: f"{o[0]} x{o[1]}")

    # Every numeric conversion (MU -> TO_MU = c) must have the reverse
    # (TO_MU -> MU) with reciprocal value, within the same OMOP_QUANTITY.
    index = {}
    for r in rows:
        c = parse_conversion(r["CONVERSION"])
        if c is None:
            continue
        index[(r[OMOP_QUANTITY], r["MEASUREMENT_UNIT"], r["TO_MEASUREMENT_UNIT"])] = c

    missing_rev = []
    for (q, mu, to_mu), c in index.items():
        if is_na(mu) or is_na(to_mu):
            continue
        rev = index.get((q, to_mu, mu))
        if rev is None:
            missing_rev.append((q, mu, to_mu, c, "no reverse row"))
        elif c != 0 and not math.isclose(c * rev, 1.0, rel_tol=1e-3):
            missing_rev.append((q, mu, to_mu, c, f"reverse={rev}, product={c*rev:.6g}"))
    rep.check("each conversion has reciprocal reverse conversion", missing_rev,
              lambda o: f"{o[0]}: {o[1]} -> {o[2]} ({o[3]}) : {o[4]}")


def validate_counts(rep, rows):
    print("\nharmonization_counts.tsv")

    empties = [(i, c) for i, r in enumerate(rows, 2)
               for c in (OMOP_ID, OMOP_QUANTITY) if is_na(r[c])]
    rep.check("OMOP_ID and OMOP_QUANTITY not empty", empties,
              lambda o: f"row {o[0]} column {o[1]} empty")

    rep.check("OMOP_ID + OMOP_QUANTITY unique",
              find_duplicates(rows, [OMOP_ID, OMOP_QUANTITY]),
              lambda o: f"{o[0]} x{o[1]}")

    allowed_src = {r["UNIT_SOURCE"] for r in rows if not is_na(r["UNIT_SOURCE"])}
    bad_src = [(i, r["UNIT_SOURCE"]) for i, r in enumerate(rows, 2)
               if r["UNIT_SOURCE"] not in allowed_src]
    rep.check(f"UNIT_SOURCE in allowed {sorted(allowed_src)}", bad_src,
              lambda o: f"row {o[0]}: {o[1]!r}")

    bad_fmt = [(i, c) for i, r in enumerate(rows, 2)
               for c in ("PREV_SOURCE", "PREV_INJECTED")
               if not valid_prev_format(r[c])]
    rep.check("PREV_SOURCE / PREV_INJECTED are {unit: fraction} dicts", bad_fmt,
              lambda o: f"row {o[0]} column {o[1]} malformed")


# --------------------------------------------------------------------------- #
# cross-table validations
# --------------------------------------------------------------------------- #
def validate_cross(rep, unitsfi, labfi, quantity, counts):
    print("\nCross-table checks")

    # An APPROVED LABfi mapping with a unit must use a unit known to UNITSfi.
    # Empty unit == qualitative test (no unit) and is allowed.
    unit_set = {r["MEASUREMENT_UNIT"] for r in unitsfi}
    missing_units = sorted({r["MEASUREMENT_UNIT"] for r in labfi
                            if r[MAPPING_STATUS] == "APPROVED"
                            and not is_na(r["MEASUREMENT_UNIT"])
                            and r["MEASUREMENT_UNIT"] not in unit_set})
    rep.check("APPROVED LABfi MEASUREMENT_UNIT exist in UNITSfi", missing_units,
              lambda o: f"{o!r}")

    # Soft: counts may hold OMOP concepts not (yet) in LABfi (e.g. unmapped
    # OMOP_QUANTITY="NA" rows). Report but don't fail.
    lab_triples = {(r[OMOP_ID], r[OMOP_QUANTITY], r["MEASUREMENT_UNIT"]) for r in labfi}
    missing_triples = [(r[OMOP_ID], r[OMOP_QUANTITY], r[COUNTS_UNIT]) for r in counts
                       if (r[OMOP_ID], r[OMOP_QUANTITY], r[COUNTS_UNIT]) not in lab_triples]
    rep.warn("all counts (OMOP_ID, OMOP_QUANTITY, UNIT) exist in LABfi",
             missing_triples, lambda o: f"{o}")

    # Every APPROVED LABfi (OMOP_QUANTITY, unit) with a unit must be defined in the
    # quantity conversion table. Empty unit == qualitative, no conversion needed.
    q_pairs = {(r[OMOP_QUANTITY], r["MEASUREMENT_UNIT"]) for r in quantity}
    missing_qu = sorted({(r[OMOP_QUANTITY], r["MEASUREMENT_UNIT"]) for r in labfi
                         if r[MAPPING_STATUS] == "APPROVED"
                         and not is_na(r["MEASUREMENT_UNIT"])} - q_pairs)
    rep.check("all APPROVED LABfi (OMOP_QUANTITY, unit) exist in quantity table",
              missing_qu, lambda o: f"OMOP_QUANTITY={o[0]!r} unit={o[1]!r}")


# --------------------------------------------------------------------------- #
def main():
    rep = Report()
    unitsfi = read_tsv(UNITSFI)
    labfi = read_tsv(LABFI)
    quantity = read_tsv(QUANTITY)
    counts = read_tsv(COUNTS)

    validate_unitsfi(rep, unitsfi)
    validate_labfi(rep, labfi)
    validate_quantity(rep, quantity)
    validate_counts(rep, counts)
    validate_cross(rep, unitsfi, labfi, quantity, counts)

    print(f"\n{'=' * 60}")
    print(f"{rep.checks} checks run, {rep.failures} failed, {rep.warnings} warning(s).")
    if rep.failures:
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
