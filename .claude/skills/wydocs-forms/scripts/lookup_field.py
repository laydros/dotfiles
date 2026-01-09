#!/usr/bin/env python3
"""
Search WyDocs field dictionaries for fields matching a description.

Usage:
    lookup_field.py "borrower address"           # Search both dictionaries
    lookup_field.py "loan maturity" --lending    # Search lending only
    lookup_field.py "member name" --msp          # Search MSP only
    lookup_field.py "address" --limit 20         # More results

This helps map PDF form fields to the correct WyDocs database field names.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional


def load_dictionary(dict_type: str) -> list[dict]:
    """Load a field dictionary JSON file."""
    script_dir = Path(__file__).parent
    data_dir = script_dir.parent / "data"

    if dict_type == "lending":
        path = data_dir / "Lending_Dictionary_clean.json"
    else:
        path = data_dir / "MSP_Dictionary_clean.json"

    if not path.exists():
        print(f"Error: Dictionary not found: {path}", file=sys.stderr)
        sys.exit(1)

    with open(path) as f:
        return json.load(f)


def tokenize(text: str) -> set[str]:
    """Split text into searchable tokens."""
    if not text:
        return set()
    # Lowercase, split on non-alphanumeric, filter short tokens
    tokens = re.split(r'[^a-zA-Z0-9]+', text.lower())
    return {t for t in tokens if len(t) >= 2}


def score_field(field: dict, query_tokens: set[str]) -> float:
    """Score how well a field matches the query tokens."""
    score = 0.0

    field_name = field.get("field_name", "")
    description = field.get("description", "")
    section = field.get("section", "")

    # Tokenize field data
    name_tokens = tokenize(field_name)
    desc_tokens = tokenize(description)
    section_tokens = tokenize(section)

    # Score matches (description matches worth more)
    for qt in query_tokens:
        # Exact token match in description (highest value)
        if qt in desc_tokens:
            score += 3.0
        # Partial match in description
        elif any(qt in dt or dt in qt for dt in desc_tokens):
            score += 1.5

        # Exact token match in field name
        if qt in name_tokens:
            score += 2.0
        # Partial match in field name
        elif any(qt in nt or nt in qt for nt in name_tokens):
            score += 1.0

        # Section match (lower value)
        if qt in section_tokens:
            score += 0.5

    # Bonus for having a description (more useful results)
    if description:
        score += 0.1

    return score


def search_fields(
    query: str,
    include_lending: bool = True,
    include_msp: bool = True,
    limit: int = 10
) -> list[tuple[dict, float, str]]:
    """
    Search for fields matching the query.

    Returns list of (field, score, source) tuples, sorted by score descending.
    """
    query_tokens = tokenize(query)
    if not query_tokens:
        print("Error: No searchable terms in query", file=sys.stderr)
        sys.exit(1)

    results = []

    if include_lending:
        lending = load_dictionary("lending")
        for field in lending:
            score = score_field(field, query_tokens)
            if score > 0:
                results.append((field, score, "Lending"))

    if include_msp:
        msp = load_dictionary("msp")
        for field in msp:
            score = score_field(field, query_tokens)
            if score > 0:
                results.append((field, score, "MSP"))

    # Sort by score descending
    results.sort(key=lambda x: x[1], reverse=True)

    return results[:limit]


def format_result(field: dict, score: float, source: str) -> str:
    """Format a single result for display."""
    lines = []
    name = field.get("field_name", "???")
    desc = field.get("description", "")
    section = field.get("section", "")
    field_type = field.get("field_type", "")
    legacy = field.get("legacy_field", "")

    lines.append(f"  {name}  ({source}, score: {score:.1f})")
    if desc:
        lines.append(f"    Description: {desc}")
    if section and section != desc:
        lines.append(f"    Section: {section}")
    if field_type:
        lines.append(f"    Type: {field_type}")
    if legacy:
        lines.append(f"    Legacy: {legacy}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Search WyDocs field dictionaries",
        epilog="Example: lookup_field.py 'borrower mailing address'"
    )
    parser.add_argument("query", help="What the field should contain (e.g., 'borrower address', 'loan maturity date')")
    parser.add_argument("--lending", action="store_true", help="Search lending dictionary only")
    parser.add_argument("--msp", action="store_true", help="Search MSP dictionary only")
    parser.add_argument("--limit", type=int, default=10, help="Max results (default: 10)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # If neither specified, search both
    include_lending = args.lending or (not args.lending and not args.msp)
    include_msp = args.msp or (not args.lending and not args.msp)

    results = search_fields(
        args.query,
        include_lending=include_lending,
        include_msp=include_msp,
        limit=args.limit
    )

    if not results:
        print(f"No fields found matching: {args.query}")
        sys.exit(0)

    if args.json:
        output = [
            {"field": f, "score": s, "source": src}
            for f, s, src in results
        ]
        print(json.dumps(output, indent=2))
    else:
        print(f"Found {len(results)} matching fields for: {args.query}\n")
        for field, score, source in results:
            print(format_result(field, score, source))
            print()


if __name__ == "__main__":
    main()
