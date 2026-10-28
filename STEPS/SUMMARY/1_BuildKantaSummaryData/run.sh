#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [--mappings <PATH_TO_DATA_MAPPINGS>]" >&2
  exit 1
fi

DATA_DIR="$1"
shift

ENV_NAME=""
MAPPINGS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --mappings)
      MAPPINGS_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/1_BuildKantaSummaryData"
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
SOURCE_DIR="$DATA_DIR/0_KantaSummaryTables"
SUMMARY_TEST_FILE="$SOURCE_DIR/summaryTest.tsv"
SUMMARY_UNIT_SOURCE_FILE="$SOURCE_DIR/summaryUnitSource.tsv"
SUMMARY_VALUES_SOURCE_FILE="$SOURCE_DIR/summaryValuesSource.tsv"
SUMMARY_VALUES_FILE="$SOURCE_DIR/summaryValues.tsv"

for f in "$SUMMARY_TEST_FILE" "$SUMMARY_UNIT_SOURCE_FILE" "$SUMMARY_VALUES_SOURCE_FILE" "$SUMMARY_VALUES_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing input file: $f" >&2
    exit 1
  fi
done
# The mapping data is read-only. Without it the harmonizationTable summary is skipped.
HARMONIZATION_TABLE_FILE=""
if [[ -n "$MAPPINGS_DIR" ]]; then
  HARMONIZATION_TABLE_FILE="$MAPPINGS_DIR/1_BuildHarmonizationTable/harmonizationTable.tsv"
  if [[ ! -f "$HARMONIZATION_TABLE_FILE" ]]; then
    echo "Missing input file: $HARMONIZATION_TABLE_FILE" >&2
    exit 1
  fi
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/buildKantaSummaryData.R" \
  "$SUMMARY_TEST_FILE" "$SUMMARY_UNIT_SOURCE_FILE" "$SUMMARY_VALUES_SOURCE_FILE" "$SUMMARY_VALUES_FILE" "$OUTDIR"

Rscript "$STEP_DIR/scripts/summariseKantaSummaryData.R" "$OUTDIR/kantaSummaryData.tsv" "$OUTDIR"

if [[ -n "$HARMONIZATION_TABLE_FILE" ]]; then
  Rscript "$STEP_DIR/scripts/summariseHarmonizationTable.R" "$HARMONIZATION_TABLE_FILE" "$OUTDIR"
fi

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/kantaSummaryData.tsv"
echo "Wrote $OUTDIR/kantaSummaryDataStats.md"
if [[ -n "$HARMONIZATION_TABLE_FILE" ]]; then
  echo "Wrote $OUTDIR/harmonizationTable.md"
fi
