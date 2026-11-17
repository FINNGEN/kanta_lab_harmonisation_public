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
OUTDIR="$DATA_DIR/3_Target/4_BuildTargetTable"
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
MEASUREMENT_FILE="$DATA_DIR/3_Target/1_GetMeasurementOmopData/measurementOmopData.tsv"
GROUPS_FILE="$DATA_DIR/3_Target/3_GetLoincGroupsData/loincGroups.tsv"
MEMBERSHIP_FILE="$DATA_DIR/3_Target/3_GetLoincGroupsData/loincGroupMembership.tsv"
UNIT_FILE="$DATA_DIR/3_Target/2a_GetHarmonisedUnitFromLab2Clean/harmonisedUnit_lab2clean.tsv"
FIX_FILE="$DATA_DIR/3_Target/2b_HarmonisedUnitFixes/harmonisedUnitFixes.tsv"
for f in "$MEASUREMENT_FILE" "$GROUPS_FILE" "$MEMBERSHIP_FILE" "$UNIT_FILE" "$FIX_FILE"; do
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
Rscript "$STEP_DIR/scripts/buildTargetTable.R" "$MEASUREMENT_FILE" "$GROUPS_FILE" "$MEMBERSHIP_FILE" "$UNIT_FILE" "$FIX_FILE" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/targetTable.tsv"
