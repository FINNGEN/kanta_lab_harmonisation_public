#!/usr/bin/env bash
set -euo pipefail

#
# --- Arguments -------------------------------------------------------------
#
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [--ngroups <N>] [--seed <N>] [--clean]" >&2
  exit 1
fi

DATA_DIR="$1"
shift

ENV_NAME=""
NGROUPS=""
SEED=""
CLEAN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --ngroups)
      NGROUPS="$2"
      shift 2
      ;;
    --seed)
      SEED="$2"
      shift 2
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DATA_DIR/FindLOINCDimensions"
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
GROUPED_FILE="$DATA_DIR/GroupKnownInformationTable/knownInformationGrouped.tsv"

if [[ ! -f "$GROUPED_FILE" ]]; then
  echo "Missing input file: $GROUPED_FILE" >&2
  exit 1
fi
if [[ ! -f "$STEP_DIR/scripts/systemPrompt.md" ]]; then
  echo "Missing input file: $STEP_DIR/scripts/systemPrompt.md" >&2
  exit 1
fi
if [[ -z "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
  echo "GOOGLE_CLOUD_PROJECT is not set (expected from the --env environment file)" >&2
  exit 1
fi
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found on PATH" >&2
  exit 1
fi

#
# --- Action -------------------------------------------------------------
#
# --clean discards the per-group LLM answer cache so every selected group is
# asked again. Needed after editing scripts/systemPrompt.md or the output
# schema: the cache is keyed on group_id alone, so without this a re-run
# silently returns answers produced by the OLD prompt. Costs a full re-run.
if [[ "$CLEAN" -eq 1 ]]; then
  if [[ -d "$OUTDIR/groupsCache" ]]; then
    echo "--clean: removing cached LLM answers in $OUTDIR/groupsCache"
    rm -rf "${OUTDIR:?}/groupsCache"
  else
    echo "--clean: no cache to remove at $OUTDIR/groupsCache"
  fi
fi

Rscript "$STEP_DIR/scripts/findLoincDimensions.R" \
  "$GROUPED_FILE" "$OUTDIR" "$NGROUPS" "$SEED"

Rscript "$STEP_DIR/scripts/summariseLoincDimensionsStats.R" \
  "$OUTDIR/codesWithLoincDimensions.tsv" "$OUTDIR/reflections.md" "$OUTDIR"

#
# --- Output -------------------------------------------------------------
#
echo "Wrote $OUTDIR/codesWithLoincDimensions.tsv"
echo "Wrote $OUTDIR/reflections.md"
echo "Wrote $OUTDIR/loincDimensionsStats.md"
