#
# Searches OMOP concepts with the Hecate API (https://hecate.pantheon-hds.com, semantic search of the OHDSI
# vocabulary), to find candidate concepts (step 3 of the fix-errors skill). See references/hecate.md.
#
# Usage:
#   python3 .claude/skills/fix-errors/scripts/hecate.py similar <concept_id> [--limit N] [--loinc | --all]
#   python3 .claude/skills/fix-errors/scripts/hecate.py search "<text>" [--limit N] [--loinc | --all]
#   python3 .claude/skills/fix-errors/scripts/hecate.py concept <concept_id>
#
# similar: the concepts closest to the name of a concept (the Similar tab of the Hecate web page).
# search:  the concepts closest to a text, e.g. a LOINC name written as Component [Property] in System.
# concept: the details of a concept and its LOINC axes (component, property, system, scale, method).
# By default standard Measurement concepts of any vocabulary, as in targetTable.tsv; --loinc only LOINC (the
# preferred vocabulary, see references/hecate.md); --all every vocabulary, domain and standard status.
# Each concept is marked with whether it is in targetTable.tsv (it can be mapped) and how many rows of
# mapping.tsv already use it.
#

#
# --- Imports -------------------------------------------------------------
#
import argparse
import collections
import csv
import json
import subprocess
import urllib.parse

#
# --- Configuration -------------------------------------------------------------
#
HECATE_URL = "https://hecate.pantheon-hds.com/api"
TARGET_FILE = "DATA/3_Target/4_BuildTargetTable/targetTable.tsv"
MAPPING_FILE = "DATA/2_Harmonisation/mapping.tsv"
AXES = ["Has component", "Has property", "Has system", "Has scale type", "Has method", "Has time aspect"]

parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["similar", "search", "concept"])
parser.add_argument("query")
parser.add_argument("--limit", type=int, default=15)
filters = parser.add_mutually_exclusive_group()
filters.add_argument("--loinc", action="store_true", help="only LOINC concepts")
filters.add_argument("--all", action="store_true", help="every vocabulary, domain and standard status")
args = parser.parse_args()
print(
    f"Configuration: action = {args.action}, query = {args.query}, limit = {args.limit}, "
    f"loinc = {args.loinc}, all = {args.all}"
)


#
# --- Input -------------------------------------------------------------
#
def get(path: str, params: dict = None) -> object:
    url = f"{HECATE_URL}/{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    # curl, not urllib: some Python installs (python.org on macOS) have no root certificates.
    result = subprocess.run(["curl", "-sSf", "-m", "60", url], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


with open(TARGET_FILE, newline="", encoding="utf-8") as f:
    target = {r["concept_id"]: r for r in csv.DictReader(f, delimiter="\t")}
with open(MAPPING_FILE, newline="", encoding="utf-8") as f:
    mappingRows = collections.Counter(r["concept_id"] for r in csv.DictReader(f, delimiter="\t"))


#
# --- Action -------------------------------------------------------------
#
def search(text: str) -> list:
    params = {"q": text, "limit": args.limit}
    if not args.all:
        params.update({"domain_id": "Measurement", "standard_concept": "S"})
    if args.loinc:
        params["vocabulary_id"] = "LOINC"
    return [(r["score"], c) for r in get("search", params) for c in r["concepts"]]


def describe(conceptId: str) -> str:
    t = target.get(conceptId)
    inTarget = f'in target ({t["has_property"]}, {t["harmonised_unit"] or "no unit"})' if t else "NOT in target"
    return f"{inTarget}, {mappingRows[conceptId]} mapping rows"


#
# --- Output -------------------------------------------------------------
#
if args.action in ("similar", "search"):
    text = args.query
    if args.action == "similar":
        text = get(f"concepts/{args.query}")[0]["concept_name"]
        print(f"Name of {args.query}: {text}")
    print("\n| score | concept_id | code | name | vocabulary | standard | OHDSI records | here |")
    print("|---|---|---|---|---|---|---|---|")
    for score, c in search(text):
        print(
            f'| {round(score or 0, 3)} | {c["concept_id"]} | {c["concept_code"]} | {c["concept_name"]} | '
            f'{c["vocabulary_id"]} | {c["standard_concept"] or ""} | {c["record_count"]:,} | '
            f'{describe(str(c["concept_id"]))} |'
        )
else:
    c = get(f"concepts/{args.query}")[0]
    print(
        f'\n{c["concept_id"]} {c["concept_code"]} {c["concept_name"]}\n{c["vocabulary_id"]}, {c["domain_id"]}, '
        f'{c["concept_class_id"]}, standard {c["standard_concept"]}, valid to {c["valid_end_date"]}, '
        f'{c["record_count"]:,} OHDSI records, {describe(args.query)}'
    )
    relationships = get(f"concepts/{args.query}/relationships")
    for axis in AXES:
        for r in relationships:
            if r["relationship_id"] == axis:
                print(f'{axis}: {r["concept_name"]}')
    for r in relationships:
        if r["relationship_id"] in ("Concept replaced by", "Maps to"):
            print(f'{r["relationship_id"]}: {r["concept_id"]} {r["concept_name"]}')
