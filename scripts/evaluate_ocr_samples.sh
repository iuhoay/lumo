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

LUMO_OCR_SAMPLE_DIR="$SAMPLE_DIR" \
LUMO_OCR_EVAL_OUTPUT_DIR="$OUTPUT_DIR" \
LUMO_OCR_EVAL_STRICT="$STRICT" \
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
