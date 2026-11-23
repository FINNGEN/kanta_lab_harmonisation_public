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
OUTDIR="$DATA_DIR/6_BuildDashboard"
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
EVALUATED_FILE="$DATA_DIR/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv"
UNIT_FIX_FILE="$DATA_DIR/2_Harmonisation/unitFix.tsv"
MEASUREMENT_FILE="$DATA_DIR/3_Target/1_GetMeasurementOmopData/measurementOmopData.tsv"
CONVERSION_FILE="$DATA_DIR/3_Target/2_GetHarmonisedUnitFromLab2Clean/loincSiConventionalConversion.tsv"
TARGET_TABLE_FILE="$DATA_DIR/3_Target/4_BuildTargetTable/targetTable.tsv"
WARNING_MISMATCH_FILE="$DATA_DIR/4_BuildHarmonisationTable/testname_unit_property_missmatch_warning.tsv"
WARNING_SHARED_FILE="$DATA_DIR/4_BuildHarmonisationTable/testname_property_shared_warning.tsv"
for f in "$EVALUATED_FILE" "$UNIT_FIX_FILE" "$WARNING_MISMATCH_FILE" "$WARNING_SHARED_FILE" "$MEASUREMENT_FILE" "$CONVERSION_FILE" "$TARGET_TABLE_FILE"; do
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
Rscript "$STEP_DIR/scripts/buildDashboard.R" "$EVALUATED_FILE" "$UNIT_FIX_FILE" \
  "$WARNING_MISMATCH_FILE" "$WARNING_SHARED_FILE" "$MEASUREMENT_FILE" "$CONVERSION_FILE" "$TARGET_TABLE_FILE" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/dashboard.html"
