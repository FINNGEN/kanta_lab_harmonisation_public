#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME> --mappings <PATH_TO_DATA_MAPPINGS>" >&2
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

if [[ -z "$MAPPINGS_DIR" ]]; then
  echo "Missing --mappings <PATH_TO_DATA_MAPPINGS>" >&2
  exit 1
fi

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/2_HarmonizeKantaSummaryData"
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
KANTA_SUMMARY_DATA_FILE="$DATA_DIR/1_BuildKantaSummaryData/kantaSummaryData.tsv"
HARMONIZATION_TABLE_FILE="$MAPPINGS_DIR/1_BuildHarmonizationTable/harmonizationTable.tsv"

for f in "$KANTA_SUMMARY_DATA_FILE" "$HARMONIZATION_TABLE_FILE"; do
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
Rscript "$STEP_DIR/scripts/harmonizeKantaSummaryData.R" \
  "$KANTA_SUMMARY_DATA_FILE" "$HARMONIZATION_TABLE_FILE" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/harmonizedKantaSummaryData.tsv"
