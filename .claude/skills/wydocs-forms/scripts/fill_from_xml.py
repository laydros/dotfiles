#!/usr/bin/env python3
"""Fill PDF form fields from WyDocs XML data."""
import sys
import argparse
import xml.etree.ElementTree as ET
import pikepdf


def extract_xml_data(xml_path):
    """Extract all tag/value pairs from XML."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    data = {}
    for elem in root.iter():
        if elem.text and elem.text.strip():
            # Use tag name as field name
            data[elem.tag] = elem.text.strip()

    return data


def fill_pdf(pdf_path, xml_data, output_path, verbose=False):
    """Fill PDF form fields with XML data."""
    with pikepdf.open(pdf_path) as pdf:
        if "/AcroForm" not in pdf.Root or "/Fields" not in pdf.Root.AcroForm:
            print("Error: PDF has no form fields", file=sys.stderr)
            return False

        filled_count = 0
        for field in pdf.Root.AcroForm.Fields:
            if "/T" not in field:
                continue

            field_name = str(field.T)
            if field_name in xml_data:
                value = xml_data[field_name]
                if value:  # Only fill non-empty values
                    field.V = value
                    filled_count += 1
                    if verbose:
                        print(f"  {field_name} = {value}")

        pdf.save(output_path)
        print(f"Filled {filled_count} fields in {output_path}")
        return True


def main():
    parser = argparse.ArgumentParser(description="Fill PDF from WyDocs XML data")
    parser.add_argument("pdf", help="Input PDF file")
    parser.add_argument("xml", help="WyDocs XML data file")
    parser.add_argument("-o", "--output", help="Output PDF file (default: modify in place)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show each field filled")

    args = parser.parse_args()

    output_path = args.output if args.output else args.pdf

    try:
        xml_data = extract_xml_data(args.xml)
        if args.verbose:
            print(f"Extracted {len(xml_data)} fields from XML")

        fill_pdf(args.pdf, xml_data, output_path, args.verbose)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
