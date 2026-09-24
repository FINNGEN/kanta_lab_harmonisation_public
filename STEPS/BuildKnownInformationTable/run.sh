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
OUTDIR="$DATA_DIR/BuildKnownInformationTable"
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
LAB_SUMMARY_FILE="$DATA_DIR/getSummaryData/labSummary.tsv"
LAB_CODES_FILE="$DATA_DIR/SourceLabelingData/lab_codes_kodistopalvely.tsv"
PREFIXES_FILE="$DATA_DIR/SourceLabelingData/code_prefixes.tsv"
SUFFIXES_FILE="$DATA_DIR/SourceLabelingData/code_suffixes.tsv"

for f in "$LAB_SUMMARY_FILE" "$LAB_CODES_FILE" "$PREFIXES_FILE" "$SUFFIXES_FILE"; do
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
Rscript "$STEP_DIR/scripts/buildKnownInformationTable.R" \
  "$LAB_SUMMARY_FILE" "$LAB_CODES_FILE" "$PREFIXES_FILE" "$SUFFIXES_FILE" "$OUTDIR"

Rscript "$STEP_DIR/scripts/summariseKnownInformationStats.R" \
  "$OUTDIR/knownInformation.tsv" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/knownInformation.tsv"
echo "Wrote $OUTDIR/knownInformationStats.md"
