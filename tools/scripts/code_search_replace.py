#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LocalAI Portable - Multi-Language Source Code Search & Replace Tool
Features:
  - Recursive scanning across project files (.py, .java, .js, .ts, .cs, .c, .cpp, .sql, etc.)
  - Encoding-aware: Auto-detects Shift_JIS/CP932 and UTF-8 per file, preserving original encoding
  - Regex or substring search and replacement with optional dry-run diff
  - Detailed line and column reports
"""

import sys
import re
import argparse
from pathlib import Path
import chardet

DEFAULT_EXTENSIONS = [
    ".py", ".java", ".js", ".ts", ".jsx", ".tsx",
    ".cs", ".c", ".cpp", ".h", ".hpp",
    ".sql", ".xml", ".json", ".yaml", ".yml",
    ".html", ".css", ".md", ".txt", ".bat", ".ps1", ".sh"
]


def detect_file_encoding(file_path: Path) -> str:
    raw = file_path.read_bytes()[:10000]
    if not raw:
        return "utf-8"
    result = chardet.detect(raw)
    enc = result.get("encoding")
    if not enc or enc.lower() in ("ascii", "iso-8859-1"):
        try:
            raw.decode("utf-8")
            return "utf-8"
        except UnicodeDecodeError:
            return "cp932"
    if "shift_jis" in enc.lower() or "windows-1252" in enc.lower():
        return "cp932"
    return enc


def search_files(target_dir: Path, pattern: str, extensions: list, is_regex: bool = False):
    compiled = re.compile(pattern if is_regex else re.escape(pattern))
    matches_count = 0
    files_count = 0

    print(f"Searching for '{pattern}' in {target_dir} across {extensions}...\n")

    for p in target_dir.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in extensions:
            continue
        # Skip version control / build dirs
        parts = p.parts
        if any(skip in parts for skip in (".git", "node_modules", ".vs", "target", "build", "dist")):
            continue

        files_count += 1
        enc = detect_file_encoding(p)
        try:
            content = p.read_text(encoding=enc, errors="replace")
        except Exception:
            continue

        file_matches = []
        for line_num, line in enumerate(content.splitlines(), start=1):
            if compiled.search(line):
                file_matches.append((line_num, line.strip()))

        if file_matches:
            print(f"[{enc}] {p.relative_to(target_dir)} ({len(file_matches)} hits):")
            for lnum, ltext in file_matches[:10]:
                print(f"   L{lnum:4d}: {ltext}")
            if len(file_matches) > 10:
                print(f"   ... and {len(file_matches) - 10} more matches.")
            matches_count += len(file_matches)
            print()

    print(f"Search complete: {matches_count} matches in {files_count} scanned files.")


def replace_in_files(target_dir: Path, pattern: str, replacement: str, extensions: list, is_regex: bool = False, dry_run: bool = True):
    compiled = re.compile(pattern if is_regex else re.escape(pattern))
    total_replaced = 0
    modified_files = 0

    mode_label = "[DRY-RUN] " if dry_run else "[REPLACING] "
    print(f"{mode_label}Replacing '{pattern}' -> '{replacement}' in {target_dir}...\n")

    for p in target_dir.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in extensions:
            continue
        parts = p.parts
        if any(skip in parts for skip in (".git", "node_modules", ".vs", "target", "build", "dist")):
            continue

        enc = detect_file_encoding(p)
        try:
            content = p.read_text(encoding=enc, errors="replace")
        except Exception:
            continue

        new_content, count = compiled.subn(replacement, content)
        if count > 0:
            total_replaced += count
            modified_files += 1
            print(f"  {p.relative_to(target_dir)}: {count} occurrences ({enc})")

            if not dry_run:
                p.write_text(new_content, encoding=enc)

    print(f"\nSummary: {total_replaced} replacements in {modified_files} files.")
    if dry_run and total_replaced > 0:
        print("Run with --execute (without --dry-run) to apply changes.")


def main():
    parser = argparse.ArgumentParser(description="Multi-Language Source Code Search & Replace")
    parser.add_argument("dir", nargs="?", default=".", help="Root directory to search (Default: current dir)")
    parser.add_argument("--search", required=True, help="Pattern to search")
    parser.add_argument("--replace", default=None, help="Replacement string (if replacing)")
    parser.add_argument("--regex", action="store_true", help="Treat pattern as regular expression")
    parser.add_argument("--ext", nargs="+", default=None, help="File extensions to scan (e.g. .java .py .sql)")
    parser.add_argument("--execute", action="store_true", help="Actually modify files (Default is dry-run)")

    args = parser.parse_args()
    target_dir = Path(args.dir).resolve()
    extensions = [e if e.startswith(".") else f".{e}" for e in args.ext] if args.ext else DEFAULT_EXTENSIONS

    if not target_dir.exists():
        print(f"Error: Target directory does not exist: {target_dir}", file=sys.stderr)
        sys.exit(1)

    if args.replace is not None:
        replace_in_files(
            target_dir=target_dir,
            pattern=args.search,
            replacement=args.replace,
            extensions=extensions,
            is_regex=args.regex,
            dry_run=(not args.execute)
        )
    else:
        search_files(
            target_dir=target_dir,
            pattern=args.search,
            extensions=extensions,
            is_regex=args.regex
        )


if __name__ == "__main__":
    main()
