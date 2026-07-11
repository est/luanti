#!/usr/bin/env python3
"""
parse_translations.py
Parses all .zh_CN.po files from MineClonia and outputs a JSON translation map.
Usage: python3 scripts/parse_translations.py mineclonia scripts/translations.json
"""

import os
import re
import json
import sys

MINECLONIA_DIR = sys.argv[1] if len(sys.argv) > 1 else "mineclonia"
OUTPUT_FILE = sys.argv[2] if len(sys.argv) > 2 else "scripts/translations.json"


def parse_po_file(path):
    """Parse a .po file and return dict of msgid -> msgstr."""
    translations = {}
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Split into entries by blank lines
    entries = re.split(r"\n\n+", content)

    for entry in entries:
        # Extract msgid and msgstr
        msgid_match = re.search(r'msgid\s+"((?:[^"\\]|\\.)*)"\s*(?:msgids|"((?:[^"\\]|\\.)*)")?', entry)
        msgstr_match = re.search(r'msgstr\s+"((?:[^"\\]|\\.)*)"\s*(?:msgstrs|"((?:[^"\\]|\\.)*)")?', entry)

        if not msgid_match or not msgstr_match:
            continue

        msgid = msgid_match.group(1)
        if msgid == "":  # Skip header
            continue

        # Handle multi-line strings
        msgid_parts = [msgid]
        msgstr_parts = [msgstr_match.group(1) or ""]

        # Find continuation lines
        for line in entry.split("\n"):
            line = line.strip()
            if line.startswith('"') and line.endswith('"'):
                # This is a continuation of the previous string
                # Determine if it's part of msgid or msgstr
                pass  # Handled by the regex above for simple cases

        msgid = "".join(msgid_parts).replace('\\"', '"').replace("\\n", "\n")
        msgstr = "".join(msgstr_parts).replace('\\"', '"').replace("\\n", "\n")

        if msgstr:  # Only include if translation exists
            translations[msgid] = msgstr

    return translations


def parse_po_file_v2(path):
    """More robust PO parser handling multi-line strings."""
    translations = {}
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    msgid = None
    msgstr = None
    in_msgid = False
    in_msgstr = False

    for line in lines:
        line = line.rstrip("\n")

        if line.startswith("msgid "):
            # Start of new msgid
            if msgid is not None and msgstr is not None and msgid != "" and msgstr != "":
                translations[msgid] = msgstr
            raw = line[6:].strip()
            if raw.startswith('"'):
                msgid = raw.strip('"')
            else:
                msgid = raw.strip('"')
            msgstr = None
            in_msgid = True
            in_msgstr = False
        elif line.startswith("msgstr "):
            raw = line[7:].strip()
            if raw.startswith('"'):
                msgstr = raw.strip('"')
            else:
                msgstr = raw.strip('"')
            in_msgid = False
            in_msgstr = True
        elif line.startswith('"') and line.endswith('"'):
            continuation = line.strip('"')
            if in_msgid and msgid is not None:
                msgid += continuation
            elif in_msgstr and msgstr is not None:
                msgstr += continuation
        elif line == "":
            in_msgid = False
            in_msgstr = False

    # Don't forget the last entry
    if msgid is not None and msgstr is not None and msgid != "" and msgstr != "":
        translations[msgid] = msgstr

    # Unescape
    result = {}
    for k, v in translations.items():
        k = k.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
        v = v.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
        result[k] = v

    return result


def main():
    print(f"Scanning {MINECLONIA_DIR} for .zh_CN.po files...")

    all_translations = {}
    file_count = 0
    entry_count = 0

    for root, dirs, files in os.walk(os.path.join(MINECLONIA_DIR, "mods")):
        for fname in files:
            if fname.endswith(".zh_CN.po"):
                path = os.path.join(root, fname)
                translations = parse_po_file_v2(path)
                for k, v in translations.items():
                    if k not in all_translations:
                        all_translations[k] = v
                        entry_count += 1
                file_count += 1

    print(f"Parsed {file_count} files, {entry_count} unique translations")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_translations, f, ensure_ascii=False, indent=None, separators=(",", ":"))

    print(f"Written to {OUTPUT_FILE} ({os.path.getsize(OUTPUT_FILE)} bytes)")


if __name__ == "__main__":
    main()
