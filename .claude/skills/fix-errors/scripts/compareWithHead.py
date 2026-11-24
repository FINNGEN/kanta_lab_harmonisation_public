#
# Compares evaluatedHarmonisedKantaAgregatedTable.tsv in the working tree with a commit (default HEAD), for the
# Result of the report of the fix-errors skill (step 6): the pairs that changed, the records newly approved,
# and the change of the counts of mapping_status and harmonisation_values_status.
#
# Usage: python3 .claude/skills/fix-errors/scripts/compareWithHead.py [<commit>]
#
# A case must start from a clean working tree, so the difference with HEAD is the case.
#

#
# --- Imports -------------------------------------------------------------
#
import collections
import csv
import io
import subprocess
import sys

#
# --- Configuration -------------------------------------------------------------
#
revision = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
EVALUATED_FILE = "DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv"
COMPARED_COLUMNS = [
    "mapping_status",
    "harmonisation_values_status",
    "UNIT",
    "concept_id",
    "target_unit",
    "HARMONISED_UNIT",
    "CONVERSION",
    "KS",
    "log10_D5",
]
print(f"Configuration: revision = {revision}")


#
# --- Input -------------------------------------------------------------
#
def readPairs(text: str) -> dict:
    rows = csv.DictReader(io.StringIO(text), delimiter="\t")
    return {(r["TEST_NAME"], r["MEASUREMENT_UNIT"]): r for r in rows}


before = readPairs(
    subprocess.run(
        ["git", "show", f"{revision}:{EVALUATED_FILE}"], capture_output=True, text=True, check=True
    ).stdout
)
with open(EVALUATED_FILE, newline="", encoding="utf-8") as f:
    after = readPairs(f.read())

#
# --- Action -------------------------------------------------------------
#
changed = [
    key
    for key in after
    if key not in before or any(before[key][c] != after[key][c] for c in COMPARED_COLUMNS)
]
changed.sort(key=lambda key: -float(after[key]["n"] or 0))
newlyApproved = [
    key
    for key in changed
    if after[key]["mapping_status"] == "APPROVED"
    and before.get(key, {}).get("mapping_status") != "APPROVED"
]


def counts(pairs: dict, column: str) -> collections.Counter:
    return collections.Counter(r[column].split(":")[0] for r in pairs.values())


#
# --- Output -------------------------------------------------------------
#
print(f"\n## Changed pairs ({len(changed)})\n")
print("| pair | n | mapping_status | values_status | concept_id | HARMONISED_UNIT | CONVERSION | KS | log10_D5 |")
print("|" + "---|" * 9)
for key in changed:
    a, b = after[key], before.get(key, {})

    def show(column: str) -> str:
        old = b.get(column, "")
        return a[column] if old == a[column] else f"{old or '(none)'} -> {a[column] or '(none)'}"

    unit = a["MEASUREMENT_UNIT"] if a["MEASUREMENT_UNIT"] == a["UNIT"] else f'{a["MEASUREMENT_UNIT"]}->{a["UNIT"]}'
    print(
        f'| {a["TEST_NAME"]}[{unit}] | {a["n"]} | {show("mapping_status")} | '
        f'{show("harmonisation_values_status")[:60]} | {show("concept_id")} | {show("HARMONISED_UNIT")} | '
        f'{show("CONVERSION")} | {a["KS"]} | {a["log10_D5"]} |'
    )

print(
    f"\nNewly APPROVED: {len(newlyApproved)} pairs, "
    f'{sum(int(float(after[k]["n"] or 0)) for k in newlyApproved):,} records'
)
for column in ["mapping_status", "harmonisation_values_status"]:
    old, new = counts(before, column), counts(after, column)
    diff = {k: (old[k], new[k]) for k in sorted(set(old) | set(new)) if old[k] != new[k]}
    print(f"\n## {column} counts that changed\n")
    for k, (o, n) in diff.items():
        print(f"- {k}: {o:,} -> {n:,}")
