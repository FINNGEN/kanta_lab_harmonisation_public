#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [--min-n <N>] [--group-size <N>]" >&2
  exit 1
fi

DATA_DIR="$1"
shift

ENV_NAME=""
MIN_N=100
GROUP_SIZE=100
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --min-n)
      MIN_N="$2"
      shift 2
      ;;
    --group-size)
      GROUP_SIZE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/GroupKnownInformationTable"
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
KNOWN_INFORMATION_FILE="$DATA_DIR/BuildKnownInformationTable/knownInformation.tsv"

if [[ ! -f "$KNOWN_INFORMATION_FILE" ]]; then
  echo "Missing input file: $KNOWN_INFORMATION_FILE" >&2
  exit 1
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
Rscript "$STEP_DIR/scripts/groupKnownInformationTable.R" \
  "$KNOWN_INFORMATION_FILE" "$OUTDIR" "$MIN_N" "$GROUP_SIZE"

Rscript "$STEP_DIR/scripts/summariseKnownInformationGroupedStats.R" \
  "$OUTDIR/knownInformationGrouped.tsv" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/knownInformationGrouped.tsv"
echo "Wrote $OUTDIR/knownInformationGroupedStats.md"
