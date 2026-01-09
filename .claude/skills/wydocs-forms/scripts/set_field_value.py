#!/usr/bin/env python3
"""
Set the value of a form field in a PDF.

Usage:
    # Set a field's value
    set_field_value.py input.pdf "FieldName" "New Value" -o output.pdf

    # Clear a field's value
    set_field_value.py input.pdf "FieldName" "" -o output.pdf

    # Modify in place (overwrites input)
    set_field_value.py input.pdf "FieldName" "New Value"
"""

import argparse
import sys
from pathlib import Path

try:
    import pikepdf
except ImportError:
    print("Error: pikepdf not installed. Run setup.sh first.", file=sys.stderr)
    sys.exit(1)


def set_field_value(pdf: pikepdf.Pdf, field_name: str, value: str) -> bool:
    """
    Set the value of a field in the PDF.

    Returns True if field was found and updated.
    """
    if "/AcroForm" not in pdf.Root:
        return False

    acroform = pdf.Root.AcroForm
    if "/Fields" not in acroform:
        return False

    def search_and_set(field_list) -> bool:
        for field in field_list:
            if "/T" in field and str(field.T) == field_name:
                if value:
                    field.V = pikepdf.String(value)
                else:
                    # Clear the value
                    if "/V" in field:
                        del field["/V"]
                return True
            if "/Kids" in field:
                if search_and_set(field.Kids):
                    return True
        return False

    return search_and_set(acroform.Fields)


def main():
    parser = argparse.ArgumentParser(
        description="Set the value of a form field in a PDF",
        epilog="Example: set_field_value.py form.pdf 'CU_NAME' 'Acme Credit Union' -o output.pdf"
    )
    parser.add_argument("input_pdf", help="Input PDF file")
    parser.add_argument("field_name", help="Field name to update")
    parser.add_argument("value", help="New value (use empty string to clear)")
    parser.add_argument("-o", "--output", help="Output PDF file (default: overwrite input)")

    args = parser.parse_args()

    input_path = Path(args.input_pdf)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path

    pdf = pikepdf.open(input_path, allow_overwriting_input=True)
    found = set_field_value(pdf, args.field_name, args.value)

    if not found:
        print(f"No field named '{args.field_name}' found")
        pdf.close()
        sys.exit(1)

    pdf.save(output_path)
    pdf.close()

    if args.value:
        print(f"Set {args.field_name} = '{args.value}'")
    else:
        print(f"Cleared {args.field_name}")
    if output_path != input_path:
        print(f"Saved to: {output_path}")


if __name__ == "__main__":
    main()
