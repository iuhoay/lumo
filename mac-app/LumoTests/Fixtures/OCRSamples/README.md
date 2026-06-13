# OCR Samples

Put real screenshot fixtures here to evaluate Lumo's OCR pipeline against
representative screen text.

Each sample needs an image and expected text with the same basename:

```text
web-small-text.png
web-small-text.expected.txt
```

Optional metadata can tune the pass threshold or mark hard cases as warnings:

```json
{
  "threshold": 0.85,
  "required": true
}
```

Suggested coverage:

- Web page body text and small UI labels.
- Dark backgrounds and low-contrast text.
- Simplified Chinese, English, and mixed Chinese/English.
- Code blocks, menus, popovers, and dialogs.
- Retina screenshots and multi-display captures.

Seed fixtures include real CleanShot captures plus generated mixed
Chinese/English samples rendered with Google Fonts Inter and Noto Sans SC.

Run:

```sh
./scripts/evaluate_ocr_samples.sh
```

The report is written to `mac-app/build/ocr-eval/` with a `summary.tsv` plus
per-sample `recognized.txt`, `expected.txt`, and `diff.txt` files.
