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
OUTDIR="$DATA_DIR/1_GetSummaryData"
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
SOURCE_DIR="$DATA_DIR/source_kanta_summary"
SUMMARY_TEST_FILE="$SOURCE_DIR/summaryTest.tsv"
SUMMARY_UNIT_SOURCE_FILE="$SOURCE_DIR/summaryUnitSource.tsv"
SUMMARY_VALUES_SOURCE_FILE="$SOURCE_DIR/summaryValuesSource.tsv"
SUMMARY_VALUES_FILE="$SOURCE_DIR/summaryValues.tsv"

for f in "$SUMMARY_TEST_FILE" "$SUMMARY_VALUES_SOURCE_FILE" "$SUMMARY_VALUES_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing input file: $f" >&2
    exit 1
  fi
done
# summaryUnitSource.tsv is optional: some source_kanta_summary vintages (e.g.
# converted from the older v3 extract) never had it. An empty arg tells the R
# script there is none, rather than erroring -- every pair's unit_source
# breakdown then reads as 100% NA, which is exactly true when no unit_source
# data exists at all.
if [[ ! -f "$SUMMARY_UNIT_SOURCE_FILE" ]]; then
  echo "Warning: $SUMMARY_UNIT_SOURCE_FILE not found -- unit_source_injection_correction_na_p will read as 100% NA for every pair" >&2
  SUMMARY_UNIT_SOURCE_FILE=""
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/getSummaryData.R" \
  "$SUMMARY_TEST_FILE" "$SUMMARY_UNIT_SOURCE_FILE" "$SUMMARY_VALUES_SOURCE_FILE" "$SUMMARY_VALUES_FILE" "$OUTDIR"

Rscript "$STEP_DIR/scripts/summariseLabSummaryStats.R" "$OUTDIR/labSummary.tsv" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/labSummary.tsv"
echo "Wrote $OUTDIR/labSummaryStats.md"
