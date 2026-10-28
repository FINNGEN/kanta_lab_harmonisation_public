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
OUTDIR="$DATA_DIR/1_BuildHarmonizationTable"
mkdir -p "$OUTDIR"

exec > >(tee "$OUTDIR/log.txt") 2>&1

#
# --- Configuration -------------------------------------------------------------
#
if [[ -n "$ENV_NAME" ]]; then
  ENV_FILE="$STEP_DIR/../../../ENVIRONMENTS/$ENV_NAME.env"
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
TABLES_DIR="$DATA_DIR/0_MappingTables"
OMOP_DIR="$DATA_DIR/0_GetMeasurementOmopData"
UNIT_FIX_FILE="$TABLES_DIR/unit_fix.tsv"
TESTNAME_UNIT_FILE="$TABLES_DIR/testname_unit_to_conceptid.tsv"
ATTRIBUTES_FILE="$OMOP_DIR/measurement_concept_attributes.tsv"
GROUPS_FILE="$OMOP_DIR/loinc_group_membership.tsv"
TARGET_UNIT_FILE="$TABLES_DIR/conceptid_target_unit.tsv"
CONVERSION_FILE="$TABLES_DIR/quantity_source_unit_conversion.tsv"

for f in "$UNIT_FIX_FILE" "$TESTNAME_UNIT_FILE" "$ATTRIBUTES_FILE" "$GROUPS_FILE" "$TARGET_UNIT_FILE" "$CONVERSION_FILE"; do
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
Rscript "$STEP_DIR/scripts/buildHarmonizationTable.R" \
  "$UNIT_FIX_FILE" "$TESTNAME_UNIT_FILE" "$ATTRIBUTES_FILE" "$GROUPS_FILE" "$TARGET_UNIT_FILE" "$CONVERSION_FILE" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/harmonizationTable.tsv"
