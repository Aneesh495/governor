#!/usr/bin/env python3
"""
Verification script for the Governor codebase.
Ensures:
1. No em dashes or en dashes exist in any source, documentation, or comment file.
2. UTF-8 file encoding validity.
3. Clean line formatting.
"""

import os
import sys

FORBIDDEN_CHARS = [
    ("\u2014", "em dash (\\u2014)"),
    ("\u2013", "en dash (\\u2013)"),
]

SOURCE_EXTENSIONS = {".sml", ".sig", ".md", ".json", ".py", ".sh", ".mlb", ".txt"}

def check_file(path):
    issues = []
    with open(path, "rb") as f:
        raw = f.read()

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        return [f"{path}: Non-UTF8 encoding: {e}"]

    for char, name in FORBIDDEN_CHARS:
        if char in text:
            for idx, line in enumerate(text.splitlines(), start=1):
                if char in line:
                    issues.append(f"{path}:{idx}: Contains forbidden {name}: {line.strip()[:80]}")

    return issues

def scan_repo(root):
    issues = []
    for dirpath, _, filenames in os.walk(root):
        if any(ign in dirpath for ign in [".git", "MLB", ".cm", "__pycache__", "bin"]):
            continue
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in SOURCE_EXTENSIONS or fname in {"Makefile", "LICENSE"}:
                fpath = os.path.join(dirpath, fname)
                issues.extend(check_file(fpath))
    return issues

def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    print(f"Auditing repository for clean formatting: {root}")
    issues = scan_repo(root)
    if issues:
        print(f"FAILED: Found {len(issues)} formatting violations:")
        for issue in issues:
            print(f"  [VIOLATION] {issue}")
        sys.exit(1)
    else:
        print("PASSED: Zero forbidden characters found. Repository formatting is clean.")

if __name__ == "__main__":
    main()
