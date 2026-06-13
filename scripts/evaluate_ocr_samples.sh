#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/mac-app"
SAMPLE_DIR="$ROOT_DIR/mac-app/LumoTests/Fixtures/OCRSamples"
OUTPUT_DIR="$PROJECT_DIR/build/ocr-eval"
STRICT=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--samples DIR] [--output DIR] [--strict]

Runs Lumo's OCRService against real screenshot fixtures.

Each sample is:
  name.png
  name.expected.txt
  name.meta.json        optional; {"threshold":0.85,"required":true}

Reports are written to:
  $OUTPUT_DIR
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --samples)
      SAMPLE_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

mkdir -p "$SAMPLE_DIR" "$OUTPUT_DIR"

if ! find "$SAMPLE_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.tiff' \) | grep -q .; then
  cat >&2 <<MESSAGE
No OCR sample images found in:
  $SAMPLE_DIR

Add screenshots next to matching .expected.txt files, then rerun this command.
MESSAGE
  exit 0
fi

# Pass configuration through the environment instead of a file. xcodebuild
# forwards TEST_RUNNER_-prefixed variables to the test process with the prefix
# stripped, so there is no config file to JSON-escape or to leak into a later
# plain `xcodebuild test` run.
TEST_RUNNER_LUMO_OCR_EVAL_SAMPLES="$SAMPLE_DIR" \
TEST_RUNNER_LUMO_OCR_EVAL_OUTPUT="$OUTPUT_DIR" \
TEST_RUNNER_LUMO_OCR_EVAL_STRICT="$STRICT" \
xcodebuild \
  -project "$PROJECT_DIR/Lumo.xcodeproj" \
  -scheme Lumo \
  -configuration Debug \
  -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
  test \
  -only-testing:LumoTests/OCRSampleEvaluationTests

echo
echo "OCR evaluation report:"
echo "  $OUTPUT_DIR/summary.tsv"
if [[ "$STRICT" != "1" ]]; then
  echo
  echo "Scores are report-only; this run passes regardless of OCR quality."
  echo "Re-run with --strict to fail when a required sample is below threshold."
fi
