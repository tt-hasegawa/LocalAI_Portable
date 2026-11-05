#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LocalAI Portable - Excel & CSV Conversion and Inspection Tool
Supports:
  - Excel (.xlsx, .xls) -> CSV
  - CSV -> Excel (.xlsx)
  - Auto-detection of Japanese encodings (CP932/Shift_JIS vs UTF-8)
  - Quick summary and preview of rows
"""

import sys
import argparse
from pathlib import Path
import chardet
import pandas as pd


def detect_file_encoding(file_path: Path) -> str:
    """Detects encoding using chardet with fallback to cp932/utf-8."""
    raw = file_path.read_bytes()[:10000]
    result = chardet.detect(raw)
    enc = result.get("encoding")
    if not enc or enc.lower() in ("ascii", "iso-8859-1"):
        # Test utf-8 or cp932
        try:
            raw.decode("utf-8")
            return "utf-8"
        except UnicodeDecodeError:
            return "cp932"
    if "shift_jis" in enc.lower() or "windows-1252" in enc.lower():
        return "cp932"
    return enc


def convert_file(src_path: Path, dst_path: Path, sheet_name=0, encoding=None):
    src_suffix = src_path.suffix.lower()
    dst_suffix = dst_path.suffix.lower()

    # Load source
    if src_suffix in (".xlsx", ".xlsm", ".xls"):
        print(f"Reading Excel: {src_path} (Sheet: {sheet_name})")
        df = pd.read_excel(src_path, sheet_name=sheet_name)
    elif src_suffix in (".csv", ".tsv", ".txt"):
        enc = encoding or detect_file_encoding(src_path)
        sep = "\t" if src_suffix == ".tsv" else ","
        print(f"Reading CSV: {src_path} (Detected Encoding: {enc})")
        df = pd.read_csv(src_path, sep=sep, encoding=enc)
    else:
        raise ValueError(f"Unsupported source format: {src_suffix}")

    print(f"Loaded {len(df)} rows, {len(df.columns)} columns.")

    # Write destination
    if dst_suffix == ".xlsx":
        print(f"Saving to Excel: {dst_path}")
        df.to_excel(dst_path, index=False, engine="openpyxl")
    elif dst_suffix in (".csv", ".tsv", ".txt"):
        out_enc = encoding or "utf-8-sig"
        sep = "\t" if dst_suffix == ".tsv" else ","
        print(f"Saving to CSV: {dst_path} (Encoding: {out_enc})")
        df.to_csv(dst_path, index=False, sep=sep, encoding=out_enc)
    else:
        raise ValueError(f"Unsupported target format: {dst_suffix}")

    print("Conversion completed successfully.")


def preview_file(file_path: Path, rows: int = 5):
    suffix = file_path.suffix.lower()
    if suffix in (".xlsx", ".xlsm", ".xls"):
        xl = pd.ExcelFile(file_path)
        print(f"Excel Sheets in {file_path.name}: {xl.sheet_names}")
        df = pd.read_excel(file_path, sheet_name=0)
    else:
        enc = detect_file_encoding(file_path)
        print(f"CSV detected encoding: {enc}")
        df = pd.read_csv(file_path, encoding=enc)

    print(f"\n--- Preview of {file_path.name} (Top {rows} rows) ---")
    print(df.head(rows))
    print(f"\nTotal rows: {len(df)}, Columns: {list(df.columns)}")


def main():
    parser = argparse.ArgumentParser(description="Excel & CSV Conversion & Inspection Tool")
    parser.add_argument("src", help="Source file (.xlsx, .xls, .csv)")
    parser.add_argument("dst", nargs="?", default=None, help="Output destination file")
    parser.add_argument("--sheet", default=0, help="Excel sheet index or name (Default: 0)")
    parser.add_argument("--encoding", default=None, help="Encoding for CSV (e.g. cp932, utf-8, utf-8-sig)")
    parser.add_argument("--preview", action="store_true", help="Preview first rows without converting")
    parser.add_argument("--rows", type=int, default=5, help="Number of rows to preview")

    args = parser.parse_args()
    src_path = Path(args.src)

    if not src_path.exists():
        print(f"Error: Source file does not exist: {src_path}", file=sys.stderr)
        sys.exit(1)

    if args.preview or not args.dst:
        preview_file(src_path, rows=args.rows)
        if not args.dst:
            return

    dst_path = Path(args.dst)
    convert_file(src_path, dst_path, sheet_name=args.sheet, encoding=args.encoding)


if __name__ == "__main__":
    main()
