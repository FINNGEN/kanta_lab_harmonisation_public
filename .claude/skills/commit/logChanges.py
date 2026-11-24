#
# Logs a commit in DATA/6_TrackChanges/TestCodeUnitChanges.tsv: adds the commit (or #<issue>:<commit>) to the
# changes of every TEST_NAME + MEASUREMENT_UNIT pair whose harmonisation the commit changed. A pair is changed
# when one of COMPARED_COLUMNS of its row of evaluatedHarmonisedKantaAgregatedTable.tsv differs between the
# commit and its parent, or when it is new and mapped (not MISSING). A change of the KS alone (e.g. its
# reference changed) is not logged.
#
# Usage: python3 .claude/skills/commit/logChanges.py <commit> [<issue_number>]
#

#
# --- Imports -------------------------------------------------------------
#
import csv
import io
import subprocess
import sys

#
# --- Configuration -------------------------------------------------------------
#
commit = subprocess.run(
    ["git", "rev-parse", "--short", sys.argv[1]], capture_output=True, text=True, check=True
).stdout.strip()
issue = sys.argv[2] if len(sys.argv) > 2 else None
entry = f"#{issue}:{commit}" if issue else commit

EVALUATED_FILE = "DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv"
CHANGES_FILE = "DATA/6_TrackChanges/TestCodeUnitChanges.tsv"
COMPARED_COLUMNS = [
    "mapping_status",
    "harmonisation_values_status",
    "UNIT",
    "concept_id",
    "target_unit",
    "HARMONISED_UNIT",
    "CONVERSION",
    "mapping_warning_messages",
]
print(f"Configuration: commit = {commit}, entry = {entry}")


#
# --- Input -------------------------------------------------------------
#
def readPairs(revision: str) -> dict:
    result = subprocess.run(
        ["git", "show", f"{revision}:{EVALUATED_FILE}"], capture_output=True, text=True
    )
    if result.returncode != 0:
        return {}
    rows = csv.DictReader(io.StringIO(result.stdout), delimiter="\t")
    # Commits before the rename of PREPROCESED_UNIT to MEASUREMENT_UNIT have the old name.
    return {
        (r["TEST_NAME"], r.get("MEASUREMENT_UNIT", r.get("PREPROCESED_UNIT", ""))): tuple(
            r.get(c, "") for c in COMPARED_COLUMNS
        )
        for r in rows
    }


before = readPairs(f"{commit}^")
after = readPairs(commit)
if not after:
    sys.exit(f"{EVALUATED_FILE} is not in {commit}")

with open(CHANGES_FILE, newline="") as f:
    changes = {
        (r["TEST_NAME"], r["MEASUREMENT_UNIT"]): r["changes"]
        for r in csv.DictReader(f, delimiter="\t")
    }

#
# --- Action -------------------------------------------------------------
#
changed = [
    key
    for key, values in after.items()
    if (key in before and before[key] != values)
    or (key not in before and values[0] != "MISSING")
]
for key in changed:
    logged = [e for e in changes.get(key, "").split(",") if e]
    if entry not in logged:
        changes[key] = ",".join(logged + [entry])
print(f"{len(changed)} pairs changed in {commit}")

#
# --- Output -------------------------------------------------------------
#
with open(CHANGES_FILE, "w", newline="") as f:
    f.write("TEST_NAME\tMEASUREMENT_UNIT\tchanges\n")
    for (testName, unit), value in sorted(changes.items()):
        f.write(f"{testName}\t{unit}\t{value}\n")
print(f"Wrote {CHANGES_FILE}")
