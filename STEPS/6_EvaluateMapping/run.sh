#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME>" >&2
  exit 1
fi

DATA_DIR="$1"
shift

ENV_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/6_EvaluateMapping"
mkdir -p "$OUTDIR"

exec > >(tee "$OUTDIR/log.txt") 2>&1

#
# --- Configuration -------------------------------------------------------------
#
if [[ -n "$ENV_NAME" ]]; then
  ENV_FILE="$STEP_DIR/../../ENVIRONMENTS/$ENV_NAME.env"
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  else
    echo "Warning: environment file not found: $ENV_FILE" >&2
  fi
fi

#
# --- Input -------------------------------------------------------------
#
CODES_WITH_OMOP_CONCEPTS_FILE="$DATA_DIR/5_FixLOINC/codesWithOmopConcepts.tsv"
MEASUREMENT_CONCEPT_ATTRIBUTES_FILE="$DATA_DIR/0_GetMeasurementOmopData/measurement_concept_attributes.tsv"
REFERENCE_MAPPING_FILE="$DATA_DIR/ReferenceMappings/lab_data_summary.csv"

# The LOINC Group file distribution (Group.csv + GroupLoincTerms.csv), used to
# score agreement at Group level as well as on the concept id. Optional, and
# deliberately not kept under DATA/: it is a licensed external vocabulary
# release. Point LOINC_GROUP_FILE_DIR at an unpacked GroupFile folder (env file
# or exported); the derived one-group-per-code index IS written to DATA/ and is
# what the report joins on.
LOINC_GROUP_FILE_DIR="${LOINC_GROUP_FILE_DIR:-$DATA_DIR/LoincGroups}"

for f in "$CODES_WITH_OMOP_CONCEPTS_FILE" "$MEASUREMENT_CONCEPT_ATTRIBUTES_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing input file: $f" >&2
    exit 1
  fi
done
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/mapLoincToOmop.R" \
  "$CODES_WITH_OMOP_CONCEPTS_FILE" "$MEASUREMENT_CONCEPT_ATTRIBUTES_FILE" "$OUTDIR"

LOINC_GROUP_INDEX_FILE=""
if [[ -f "$LOINC_GROUP_FILE_DIR/Group.csv" && -f "$LOINC_GROUP_FILE_DIR/GroupLoincTerms.csv" ]]; then
  Rscript "$STEP_DIR/scripts/buildLoincGroupIndex.R" \
    "$LOINC_GROUP_FILE_DIR" "$OUTDIR"
  LOINC_GROUP_INDEX_FILE="$OUTDIR/loincGroupIndex.tsv"
else
  echo "No LOINC Group file at $LOINC_GROUP_FILE_DIR -- skipping Group-level agreement" >&2
fi

Rscript "$STEP_DIR/scripts/summariseLoincToOmopMapping.R" \
  "$OUTDIR/codesWithOMOP.tsv" "$REFERENCE_MAPPING_FILE" "$OUTDIR" \
  "$MEASUREMENT_CONCEPT_ATTRIBUTES_FILE" "$LOINC_GROUP_INDEX_FILE"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/codesWithOMOP.tsv"
if [[ -n "$LOINC_GROUP_INDEX_FILE" ]]; then
  echo "Wrote $OUTDIR/loincGroupIndex.tsv"
fi
echo "Wrote $OUTDIR/loincToOmopMappingStats.md"
