#!/usr/bin/env python3
"""
Get the value of a form field (or all fields) in a PDF.

Usage:
    # Get a specific field's value
    get_field_value.py input.pdf "FieldName"

    # Get all field values
    get_field_value.py input.pdf --all

    # Get all non-empty field values
    get_field_value.py input.pdf --all --non-empty
"""

import argparse
import sys
from pathlib import Path

try:
    import pikepdf
except ImportError:
    print("Error: pikepdf not installed. Run setup.sh first.", file=sys.stderr)
    sys.exit(1)


def get_field_value(pdf: pikepdf.Pdf, field_name: str) -> tuple[bool, str]:
    """
    Get the value of a field in the PDF.

    Returns (found, value) tuple.
    """
    if "/AcroForm" not in pdf.Root:
        return False, ""

    acroform = pdf.Root.AcroForm
    if "/Fields" not in acroform:
        return False, ""

    def search_field(field_list) -> tuple[bool, str]:
        for field in field_list:
            if "/T" in field and str(field.T) == field_name:
                if "/V" in field:
                    return True, str(field.V)
                return True, ""
            if "/Kids" in field:
                found, val = search_field(field.Kids)
                if found:
                    return found, val
        return False, ""

    return search_field(acroform.Fields)


def get_all_field_values(pdf: pikepdf.Pdf, non_empty_only: bool = False) -> list[tuple[str, str]]:
    """
    Get all field names and values.

    Returns list of (name, value) tuples.
    """
    results = []

    if "/AcroForm" not in pdf.Root:
        return results

    acroform = pdf.Root.AcroForm
    if "/Fields" not in acroform:
        return results

    def collect_fields(field_list):
        for field in field_list:
            if "/T" in field:
                name = str(field.T)
                value = str(field.V) if "/V" in field else ""
                if not non_empty_only or value:
                    results.append((name, value))
            if "/Kids" in field:
                collect_fields(field.Kids)

    collect_fields(acroform.Fields)
    return sorted(results, key=lambda x: x[0])


def main():
    parser = argparse.ArgumentParser(
        description="Get the value of form field(s) in a PDF",
        epilog="Example: get_field_value.py form.pdf 'CU_NAME'"
    )
    parser.add_argument("input_pdf", help="Input PDF file")
    parser.add_argument("field_name", nargs="?", help="Field name to look up")
    parser.add_argument("--all", action="store_true", help="Get all field values")
    parser.add_argument("--non-empty", action="store_true", help="Only show non-empty values (with --all)")

    args = parser.parse_args()

    if not args.field_name and not args.all:
        parser.error("Either field_name or --all is required")

    input_path = Path(args.input_pdf)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    pdf = pikepdf.open(input_path)

    if args.all:
        fields = get_all_field_values(pdf, non_empty_only=args.non_empty)
        if not fields:
            print("No fields found")
        else:
            for name, value in fields:
                if value:
                    print(f"{name} = {value}")
                else:
                    print(f"{name} = (empty)")
    else:
        found, value = get_field_value(pdf, args.field_name)
        if not found:
            print(f"No field named '{args.field_name}' found")
            pdf.close()
            sys.exit(1)
        if value:
            print(value)
        else:
            print("(empty)")

    pdf.close()


if __name__ == "__main__":
    main()
