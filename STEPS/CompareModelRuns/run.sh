#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME> --run <LABEL>=<PATH_TO_DATA_FOLDER> [--run ...]" >&2
  exit 1
fi

DATA_DIR="$1"
shift

ENV_NAME=""
RUNS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --run)
      RUNS+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ${#RUNS[@]} -lt 2 ]]; then
  echo "At least two --run <LABEL>=<PATH> arguments are needed; there is nothing to compare otherwise" >&2
  exit 1
fi

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/CompareModelRuns"
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
# The reference mapping is taken from the FIRST run: all runs read the same
# upstream folders (the others link to them), and the comparison is meaningless
# if they do not.
REFERENCE_MAPPING_FILE=""
for spec in "${RUNS[@]}"; do
  label="${spec%%=*}"
  path="${spec#*=}"
  if [[ "$label" == "$spec" || -z "$label" || -z "$path" ]]; then
    echo "Malformed --run argument: $spec (expected <LABEL>=<PATH>)" >&2
    exit 1
  fi
  for f in "$path/MapLOINCToOmop/codesWithOMOP.tsv" \
           "$path/FixLOINCDimensions/codesWithOmopConcepts.tsv"; do
    if [[ ! -f "$f" ]]; then
      echo "Missing input file: $f (run FindLOINCDimensions, FixLOINCDimensions and MapLOINCToOmop on $path first)" >&2
      exit 1
    fi
  done
  if [[ -z "$REFERENCE_MAPPING_FILE" ]]; then
    REFERENCE_MAPPING_FILE="$path/ReferenceMappings/lab_data_summary.csv"
  fi
done

if [[ ! -f "$REFERENCE_MAPPING_FILE" ]]; then
  echo "Missing input file: $REFERENCE_MAPPING_FILE" >&2
  exit 1
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/compareModelRuns.R" \
  "$REFERENCE_MAPPING_FILE" "$OUTDIR" "${RUNS[@]}"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/modelComparisonStats.md"
echo "Wrote $OUTDIR/perRowComparison.tsv"
