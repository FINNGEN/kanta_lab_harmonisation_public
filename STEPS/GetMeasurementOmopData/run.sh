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
OUTDIR="$DATA_DIR/GetMeasurementOmopData"
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
if [[ -z "${FG_DATABASE_ENV:-}" ]]; then
  echo "FG_DATABASE_ENV is not set (expected from the --env environment file)" >&2
  exit 1
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/pullMeasurementConceptAttributes.R" "$OUTDIR"
Rscript "$STEP_DIR/scripts/summariseMeasurementConceptAttributes.R" "$OUTDIR/measurement_concept_attributes.tsv" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/measurement_concept_attributes.tsv"
echo "Wrote $OUTDIR/measurement_concept_attributes_summary.md"
