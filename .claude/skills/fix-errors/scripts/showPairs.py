#
# Shows the evidence of a case (step 2 of the fix-errors skill): the pairs of
# evaluatedHarmonisedKantaAgregatedTable.tsv whose TEST_NAME contains one of the patterns or whose concept_id or
# group_concept_id is one of the given ids, their rows of mapping.tsv and unitFix.tsv, and the target units
# lab2clean gives the concepts of their properties (to tell a wrong target unit from a missing rule).
#
# Usage: python3 .claude/skills/fix-errors/scripts/showPairs.py <pattern|concept_id> [...] [--min-n N]
#
# A number is taken as a concept_id or group_concept_id, anything else as a part of TEST_NAME. Pairs with
# fewer than --min-n records (default 0) are left out of the pairs table.
#

#
# --- Imports -------------------------------------------------------------
#
import argparse
import collections
import csv

#
# --- Configuration -------------------------------------------------------------
#
EVALUATED_FILE = "DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv"
MAPPING_FILE = "DATA/2_Harmonisation/mapping.tsv"
UNIT_FIX_FILE = "DATA/2_Harmonisation/unitFix.tsv"
TARGET_FILE = "DATA/3_Target/4_BuildTargetTable/targetTable.tsv"

parser = argparse.ArgumentParser()
parser.add_argument("terms", nargs="+")
parser.add_argument("--min-n", type=float, default=0)
args = parser.parse_args()
ids = {t for t in args.terms if t.isdigit()}
patterns = [t.lower() for t in args.terms if not t.isdigit()]
print(f"Configuration: ids = {sorted(ids)}, patterns = {patterns}, min_n = {args.min_n}")


#
# --- Input -------------------------------------------------------------
#
def readTable(path: str) -> list:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


evaluated = readTable(EVALUATED_FILE)
mapping = readTable(MAPPING_FILE)
unitFix = readTable(UNIT_FIX_FILE)
target = readTable(TARGET_FILE)


#
# --- Action -------------------------------------------------------------
#
def matches(r: dict) -> bool:
    return (
        r["concept_id"] in ids
        or r["group_concept_id"] in ids
        or any(p in r["TEST_NAME"].lower() for p in patterns)
    )


pairs = sorted(
    (r for r in evaluated if matches(r) and float(r["n"] or 0) >= args.min_n),
    key=lambda r: (r["concept_id"], -float(r["n"] or 0)),
)
testNames = {r["TEST_NAME"] for r in pairs}
conceptIds = {r["concept_id"] for r in pairs if r["concept_id"] not in ("", "0")} | ids
properties = {r["has_property"] for r in target if r["concept_id"] in conceptIds} - {""}


def cell(value: str) -> str:
    return value.replace("|", "/")


#
# --- Output -------------------------------------------------------------
#
print(f"\n## Pairs ({len(pairs)})\n")
print(
    "| mapping_status | values_status | pair | n | subjects | concept_id | concept_name | property | target_unit "
    "(source) | group | HARMONISED_UNIT | CONVERSION | KS | log10_D5 | reference_range | test_outcome | deciles |"
)
print("|" + "---|" * 17)
for r in pairs:
    unit = r["MEASUREMENT_UNIT"] if r["MEASUREMENT_UNIT"] == r["UNIT"] else f'{r["MEASUREMENT_UNIT"]}->{r["UNIT"]}'
    print(
        "| "
        + " | ".join(
            cell(v)
            for v in [
                r["mapping_status"],
                r["harmonisation_values_status"][:30],
                f'{r["TEST_NAME"]}[{unit}]',
                r["n"],
                r["n_subjects"],
                r["concept_id"],
                r["concept_name"][:50],
                r["has_property"],
                f'{r["target_unit"]} ({r["target_unit_source"][:20]})',
                r["group_concept_id"],
                r["HARMONISED_UNIT"],
                r["CONVERSION"],
                r["KS"],
                r["log10_D5"],
                r["reference_range"][:40],
                r["test_outcome"][:30],
                r["decile_value"],
            ]
        )
        + " |"
    )

print("\n## mapping.tsv rows of these TEST_NAMEs or concepts\n")
for r in mapping:
    if r["TEST_NAME"] in testNames or r["concept_id"] in conceptIds:
        print("\t".join(r.values()))

print("\n## unitFix.tsv rows of these TEST_NAMEs\n")
for r in unitFix:
    if r["TEST_NAME"] in testNames:
        print("\t".join(v or "" for v in r.values()))

print("\n## Concepts and their Groups (targetTable.tsv)\n")
for r in target:
    if r["concept_id"] in conceptIds or r["group_concept_id"] in ids:
        print(
            f'{r["concept_id"]}\t{r["concept_code"]}\t{r["concept_name"][:70]}\t{r["has_property"]}\t'
            f'{r["has_system"]}\t{r["has_scale_type"]}\t{r["harmonised_unit"]} ({r["harmonised_unit_source"]})\t'
            f'group {r["group_concept_id"]}'
        )

print("\n## Target units of the concepts of these properties (targetTable.tsv)\n")
for prop in sorted(properties):
    units = collections.Counter(
        (r["harmonised_unit"], r["harmonised_unit_source"]) for r in target if r["has_property"] == prop
    )
    print(f"{prop}: " + "; ".join(f"{u or '(none)'} [{s}] {n}" for (u, s), n in units.most_common(10)))
