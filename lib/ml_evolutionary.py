#!/usr/bin/env python3
"""
Evolutionary ML module for DJProducerTools.
Handles training of a lightweight RandomForest model on file metadata features
to predict potential issues/duplicates based on user's past decisions (plans).
"""
import argparse
import csv
import os
import pathlib
import sys
from collections import defaultdict
from typing import List, Dict, Any

# Optional imports handled gracefully
try:
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import OneHotEncoder
    from sklearn.compose import ColumnTransformer
    from sklearn.pipeline import Pipeline
    from sklearn.metrics import classification_report
    import joblib
except ImportError:
    pd = None
    RandomForestClassifier = None

def check_deps():
    if pd is None or RandomForestClassifier is None:
        print("[ERR] Missing ML dependencies (pandas, scikit-learn, joblib).", file=sys.stderr)
        sys.exit(1)

def extract_features(path_str: str, label: int = None) -> Dict[str, Any]:
    p = pathlib.Path(path_str)
    try:
        stat = p.stat()
        size = stat.st_size
    except FileNotFoundError:
        size = 0
    
    name = p.name
    return {
        "path": str(p),
        "label": label,
        "size": size,
        "depth": len(p.parts),
        "name_len": len(name),
        "ext": p.suffix.lower() or "<none>",
        "underscores": name.count("_"),
        "brackets": name.count("(") + name.count("[") + name.count("{"),
        "digits": sum(c.isdigit() for c in name),
    }

def train_model(args):
    check_deps()
    plan_hash = pathlib.Path(args.plan_hash) if args.plan_hash else None
    plan_name = pathlib.Path(args.plan_name) if args.plan_name else None
    base = pathlib.Path(args.base)
    
    rows = []
    
    # Priority 1: Hash plan (Exact duplicates decisions)
    if plan_hash and plan_hash.exists() and plan_hash.stat().st_size > 0:
        with plan_hash.open() as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 3: continue
                _, action, path = parts[0], parts[1], parts[2]
                # Label 1 = Suspect/Duplicate (QUARANTINE/REMOVE), 0 = Safe (KEEP)
                label = 1 if action.upper() != "KEEP" else 0
                rows.append(extract_features(path, label))
                
    # Priority 2: Name plan (Fuzzy duplicates)
    elif plan_name and plan_name.exists() and plan_name.stat().st_size > 0:
        seen_keys = defaultdict(int)
        with plan_name.open() as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 2: continue
                key, path = parts[0], parts[1]
                seen_keys[key] += 1
                label = 1 if seen_keys[key] >= 1 else 0
                rows.append(extract_features(path, label))
    
    else:
        # Fallback: Sample generic files (unlabeled/negative mostly)
        print("[INFO] No plans found. Sampling base path for initial structure...", file=sys.stderr)
        count = 0
        limit = 2000
        for p in base.rglob("*"):
            if p.is_file():
                rows.append(extract_features(str(p), 0))
                count += 1
                if count >= limit: break

    if not rows:
        print("[ERR] No data to train on.", file=sys.stderr)
        sys.exit(2)

    # Save features dump
    if args.features_out:
        out_path = pathlib.Path(args.features_out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", newline="") as fw:
            if rows:
                keys = list(rows[0].keys())
                w = csv.DictWriter(fw, fieldnames=keys, delimiter="\t")
                w.writeheader()
                w.writerows(rows)

    df = pd.DataFrame(rows)
    if df["label"].nunique() < 2:
        print("[WARN] Not enough class diversity (need both positive and negative samples). Training skipped.", file=sys.stderr)
        sys.exit(3)

    cat_cols = ["ext"]
    num_cols = ["size", "depth", "name_len", "underscores", "brackets", "digits"]
    
    pre = ColumnTransformer(
        transformers=[
            ("cat", OneHotEncoder(handle_unknown="ignore", max_categories=50), cat_cols),
            ("num", "passthrough", num_cols),
        ]
    )
    
    clf = RandomForestClassifier(n_estimators=80, max_depth=None, random_state=42, n_jobs=2)
    pipe = Pipeline([("prep", pre), ("clf", clf)])
    
    X = df[cat_cols + num_cols]
    y = df["label"]
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)
    pipe.fit(X_train, y_train)
    
    y_pred = pipe.predict(X_test)
    report = classification_report(y_test, y_pred, output_dict=True)
    
    if args.model_out:
        out_path = pathlib.Path(args.model_out)
        if out_path.exists():
            print(f"[WARN] Existing model found at {out_path}", file=sys.stderr)
            choice = input("Overwrite? (y/N): ").strip().lower()
            if choice != 'y':
                print("[INFO] Training cancelled by user.", file=sys.stderr)
                sys.exit(0)
        
        out_path.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump({"model": pipe, "features": cat_cols + num_cols}, out_path)
        print(f"[OK] Model saved to {out_path}")
        print(f"[INFO] F1 Score: {report.get('macro avg', {}).get('f1-score', 0):.3f}")

def predict_model(args):
    check_deps()
    model_path = pathlib.Path(args.model_in)
    if not model_path.exists():
        print(f"[ERR] Model not found at {model_path}", file=sys.stderr)
        sys.exit(1)
        
    base = pathlib.Path(args.base)
    loaded = joblib.load(model_path)
    pipe = loaded["model"]
    cols = loaded["features"]
    
    rows = []
    limit = args.limit
    count = 0
    
    for p in base.rglob("*"):
        if p.is_file():
            rows.append(extract_features(str(p)))
            count += 1
            if count >= limit: break
            
    if not rows:
        print("[ERR] No files found to predict.", file=sys.stderr)
        sys.exit(1)
        
    df = pd.DataFrame(rows)
    # Ensure all expected columns exist
    for c in cols:
        if c not in df.columns:
            df[c] = 0
            
    X = df[cols]
    probs = pipe.predict_proba(X)[:, 1]
    
    results = pd.DataFrame({"prob": probs, "path": df["path"]})
    results.sort_values("prob", ascending=False, inplace=True)
    
    if args.report_out:
        out_path = pathlib.Path(args.report_out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        results.to_csv(out_path, sep="\t", index=False)
        print(f"[OK] Predictions saved to {out_path}")
        
    # Print top suspects
    print("[INFO] Top 5 suspects:")
    for _, row in results.head(5).iterrows():
        print(f"  {row['prob']:.3f}\t{row['path']}")

def main():
    parser = argparse.ArgumentParser(description="DJProducerTools Evolutionary ML Helper")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Train command
    train_parser = subparsers.add_parser("train", help="Train the model")
    train_parser.add_argument("--base", required=True, help="Base path for scanning")
    train_parser.add_argument("--plan-hash", help="Path to dupes_plan (hash)")
    train_parser.add_argument("--plan-name", help="Path to dupes_plan (name)")
    train_parser.add_argument("--features-out", help="Path to save features TSV")
    train_parser.add_argument("--model-out", required=True, help="Path to save model PKL")
    
    # Predict command
    pred_parser = subparsers.add_parser("predict", help="Predict using the model")
    pred_parser.add_argument("--base", required=True, help="Base path for scanning")
    pred_parser.add_argument("--model-in", required=True, help="Path to load model PKL")
    pred_parser.add_argument("--report-out", help="Path to save prediction report")
    pred_parser.add_argument("--limit", type=int, default=5000, help="Max files to scan")
    
    args = parser.parse_args()
    
    if args.command == "train":
        train_model(args)
    elif args.command == "predict":
        predict_model(args)

if __name__ == "__main__":
    main()
