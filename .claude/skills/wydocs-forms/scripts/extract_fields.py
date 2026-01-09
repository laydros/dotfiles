#!/usr/bin/env python3
"""
Extract form fields from a PDF file.

Usage: extract_fields.py <pdf_path> [--format json|text]

This script must be run with the skill's venv python:
    ~/.claude/skills/wydocs-forms/.venv/bin/python scripts/extract_fields.py form.pdf

Or use the wrapper script:
    scripts/extract_fields form.pdf
"""

import argparse
import json
import sys
from pathlib import Path

try:
    from pypdf import PdfReader
    from pypdf.constants import AnnotationDictionaryAttributes as ADA
except ImportError:
    print("Error: pypdf not installed. Run setup.sh first.", file=sys.stderr)
    sys.exit(1)


def extract_fields(pdf_path: Path) -> dict:
    """Extract all form fields from a PDF."""
    reader = PdfReader(pdf_path)

    fields = {
        "text_fields": [],
        "checkboxes": [],
        "signature_fields": [],
        "other_fields": [],
    }

    if reader.get_fields() is None:
        return fields

    for name, field in reader.get_fields().items():
        field_type = field.get("/FT", "")
        field_info = {
            "name": name,
            "type": str(field_type),
        }

        # Add value if present
        if "/V" in field:
            field_info["value"] = str(field["/V"])

        # Add default value if present
        if "/DV" in field:
            field_info["default"] = str(field["/DV"])

        # Categorize by type
        if field_type == "/Sig":
            fields["signature_fields"].append(field_info)
        elif field_type == "/Btn":
            fields["checkboxes"].append(field_info)
        elif field_type == "/Tx":
            fields["text_fields"].append(field_info)
        else:
            fields["other_fields"].append(field_info)

    return fields


def format_text(fields: dict) -> str:
    """Format fields as human-readable text."""
    lines = []

    lines.append(f"=== Text Fields ({len(fields['text_fields'])}) ===")
    for f in sorted(fields["text_fields"], key=lambda x: x["name"]):
        lines.append(f"  {f['name']}")

    lines.append(f"\n=== Checkboxes ({len(fields['checkboxes'])}) ===")
    for f in sorted(fields["checkboxes"], key=lambda x: x["name"]):
        lines.append(f"  {f['name']}")

    lines.append(f"\n=== Signature Fields ({len(fields['signature_fields'])}) ===")
    for f in sorted(fields["signature_fields"], key=lambda x: x["name"]):
        lines.append(f"  {f['name']}")

    if fields["other_fields"]:
        lines.append(f"\n=== Other Fields ({len(fields['other_fields'])}) ===")
        for f in sorted(fields["other_fields"], key=lambda x: x["name"]):
            lines.append(f"  {f['name']} (type: {f['type']})")

    total = sum(len(v) for v in fields.values())
    lines.append(f"\nTotal: {total} fields")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Extract form fields from a PDF")
    parser.add_argument("pdf_path", help="Path to the PDF file")
    parser.add_argument("--format", choices=["json", "text"], default="text",
                        help="Output format (default: text)")
    args = parser.parse_args()

    pdf_path = Path(args.pdf_path)
    if not pdf_path.exists():
        print(f"Error: File not found: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    fields = extract_fields(pdf_path)

    if args.format == "json":
        print(json.dumps(fields, indent=2))
    else:
        print(format_text(fields))


if __name__ == "__main__":
    main()
