#!/usr/bin/env python3
"""
Optional experiment: TF–IDF + logistic regression to predict `bank` from raw SMS.

The production Flutter app does NOT load this model. Parsing is done on-device by
`lib/services/local_parser_service.dart`, validated by:
  flutter test test/kaggle_dataset_conformance_test.dart
  flutter test test/local_parser_bank_sms_test.dart

Use this script only if you want to prototype bank routing in Python or export data
for Kaggle — not for shipping inside the APK.

Usage (from repo root `money_lens/`):
  python3 -m venv .venv-train && source .venv-train/bin/activate
  pip install -r scripts/requirements-train.txt
  python3 scripts/train_sms_lightweight.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "indian_bank_sms_labeled.jsonl"
ARTIFACTS = ROOT / "scripts" / "artifacts"


def load_rows():
    rows = []
    with DATA.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def main() -> int:
    if not DATA.is_file():
        print(f"Missing dataset: {DATA}", file=sys.stderr)
        return 1

    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.linear_model import LogisticRegression
        from sklearn.pipeline import Pipeline
        import joblib
    except ImportError:
        print("Install deps: pip install -r scripts/requirements-train.txt", file=sys.stderr)
        return 1

    rows = load_rows()
    labeled = [r for r in rows if r.get("labels", {}).get("skip") is not True and r.get("bank")]
    if len(labeled) < 2:
        print("Need at least 2 labeled bank rows in JSONL.", file=sys.stderr)
        return 1

    X = [r["raw"] for r in labeled]
    y = [r["bank"] for r in labeled]

    clf = Pipeline(
        [
            (
                "tfidf",
                TfidfVectorizer(
                    lowercase=True,
                    ngram_range=(1, 2),
                    max_features=2048,
                    min_df=1,
                ),
            ),
            (
                "lr",
                LogisticRegression(max_iter=500, class_weight="balanced"),
            ),
        ]
    )
    clf.fit(X, y)

    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    out = ARTIFACTS / "sms_bank_classifier.joblib"
    joblib.dump({"model": clf, "schema_version": 1}, out)
    print(f"Wrote {out} (trained on {len(labeled)} rows).")
    print("Integrating this .joblib into Flutter requires TFLite/ONNX conversion or a small native bridge — not wired in the app yet.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
