#!/usr/bin/env python3
"""
Rename a form field in a PDF.

Usage:
    # Rename all fields with this name (default, most common)
    rename_field.py input.pdf "OldName" "NewName" -o output.pdf

    # Rename only the first instance
    rename_field.py input.pdf "OldName" "NewName" -o output.pdf --single

    # Modify in place (overwrites input)
    rename_field.py input.pdf "OldName" "NewName"
"""

import argparse
import sys
from pathlib import Path

try:
    import pikepdf
except ImportError:
    print("Error: pikepdf not installed. Run setup.sh first.", file=sys.stderr)
    sys.exit(1)


def rename_fields(pdf: pikepdf.Pdf, old_name: str, new_name: str, single_only: bool = False) -> int:
    """
    Rename field(s) in the PDF.

    Returns count of fields renamed.
    """
    if "/AcroForm" not in pdf.Root:
        return 0

    acroform = pdf.Root.AcroForm
    if "/Fields" not in acroform:
        return 0

    count = 0

    def search_and_rename(field_list) -> bool:
        nonlocal count
        for field in field_list:
            if "/T" in field and str(field.T) == old_name:
                field.T = pikepdf.String(new_name)
                count += 1
                if single_only:
                    return True  # Stop after first
            if "/Kids" in field:
                if search_and_rename(field.Kids):
                    return True
        return False

    search_and_rename(acroform.Fields)
    return count


def main():
    parser = argparse.ArgumentParser(
        description="Rename a form field in a PDF",
        epilog="Example: rename_field.py form.pdf 'Text1' 'P_FIRST_NAME' -o output.pdf"
    )
    parser.add_argument("input_pdf", help="Input PDF file")
    parser.add_argument("old_name", help="Current field name")
    parser.add_argument("new_name", help="New field name")
    parser.add_argument("-o", "--output", help="Output PDF file (default: overwrite input)")
    parser.add_argument("--single", action="store_true",
                        help="Only rename first instance (default: rename all)")

    args = parser.parse_args()

    input_path = Path(args.input_pdf)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path

    pdf = pikepdf.open(input_path, allow_overwriting_input=True)
    count = rename_fields(pdf, args.old_name, args.new_name, single_only=args.single)

    if count == 0:
        print(f"No field named '{args.old_name}' found")
        pdf.close()
        sys.exit(1)

    pdf.save(output_path)
    pdf.close()

    print(f"Renamed {count} field(s): {args.old_name} -> {args.new_name}")
    if output_path != input_path:
        print(f"Saved to: {output_path}")


if __name__ == "__main__":
    main()
