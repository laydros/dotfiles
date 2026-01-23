---
name: wydocs-forms
description: Map PDF form fields for WyDocs integration with credit union core software. Use when reviewing PDF forms, setting up signature fields, checking field naming conventions, updating CUNAmapping.csv, or troubleshooting form population issues. Keywords: PDF, form fields, CUNA, loan documents, MSP, digital signatures, field mapping.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
---

# WyDocs Form Mapping Assistant

Help map PDF form fields for WyDocs integration with credit union core software. WyDocs automatically populates PDF forms with member and loan data.

## When to Use

Invoke with `/wydocs-forms` when:
- Reviewing PDF forms for field mapping
- Setting up digital signature fields
- Checking field naming conventions
- Updating the CUNAmapping.csv file
- Troubleshooting why a field isn't populating

## Important Warnings

**NEVER search or find over /Volumes/m3db, /home/m3db, or the H: drive.** This is a massive, slow file share. Always ask the user for specific file paths instead of searching.

## Available Scripts

This skill includes utility scripts in `~/.claude/skills/wydocs-forms/scripts/`. Use these to extract PDF form data:

### extract_fields
Extract all form fields from a PDF, categorized by type.

```bash
~/.claude/skills/wydocs-forms/scripts/extract_fields /path/to/form.pdf
~/.claude/skills/wydocs-forms/scripts/extract_fields /path/to/form.pdf --format json
```

Output includes text fields, checkboxes, signature fields, and other field types with their names and current values.

**Always run this first** when analyzing a new PDF to get the complete field inventory.

### lookup_field
Search the WyDocs field dictionaries to find the right database field for a form field.

```bash
# Search both Lending and MSP dictionaries
~/.claude/skills/wydocs-forms/scripts/lookup_field "borrower mailing address"

# Search only Lending dictionary
~/.claude/skills/wydocs-forms/scripts/lookup_field "loan maturity date" --lending

# Search only MSP dictionary
~/.claude/skills/wydocs-forms/scripts/lookup_field "member name" --msp

# Get more results
~/.claude/skills/wydocs-forms/scripts/lookup_field "address" --limit 20
```

Use this to find the correct WyDocs field name when you see a form label like "Borrower's Street Address" - the script searches field names and descriptions, returning ranked matches.

**Use this when mapping form fields** to find the best WyDocs database field to populate that location.

### rename_field_name
Rename a form field's name (not its value) in a PDF.

```bash
# Rename all fields with this name (default)
~/.claude/skills/wydocs-forms/scripts/rename_field_name input.pdf "Text1" "P_FIRST_NAME" -o output.pdf

# Rename only the first instance
~/.claude/skills/wydocs-forms/scripts/rename_field_name input.pdf "Text1" "P_FIRST_NAME" -o output.pdf --single

# Modify in place (no -o flag)
~/.claude/skills/wydocs-forms/scripts/rename_field_name input.pdf "Text1" "P_FIRST_NAME"
```

Use this to rename PDF form fields to their correct WyDocs field names.

### get_field_value
Get the value of a form field (or all fields) in a PDF.

```bash
# Get a specific field's value
~/.claude/skills/wydocs-forms/scripts/get_field_value input.pdf "CU_NAME"

# Get all field values
~/.claude/skills/wydocs-forms/scripts/get_field_value input.pdf --all

# Get only non-empty field values
~/.claude/skills/wydocs-forms/scripts/get_field_value input.pdf --all --non-empty
```

Use this to inspect current field values in a PDF.

### set_field_value
Set or clear the value of a form field in a PDF.

```bash
# Set a field's value
~/.claude/skills/wydocs-forms/scripts/set_field_value input.pdf "CU_NAME" "Acme Credit Union" -o output.pdf

# Clear a field's value (empty string)
~/.claude/skills/wydocs-forms/scripts/set_field_value input.pdf "FieldName" ""

# Modify in place (no -o flag)
~/.claude/skills/wydocs-forms/scripts/set_field_value input.pdf "CU_NAME" "Acme Credit Union"
```

Use this to set or clear field values in PDFs.

### fill_from_xml
Fill PDF form fields from WyDocs XML data files.

```bash
# Fill PDF from XML data
~/.claude/skills/wydocs-forms/scripts/fill_from_xml input.pdf data.xml -o output.pdf

# Modify in place (no -o flag)
~/.claude/skills/wydocs-forms/scripts/fill_from_xml input.pdf data.xml

# Verbose output showing each field filled
~/.claude/skills/wydocs-forms/scripts/fill_from_xml input.pdf data.xml -o output.pdf -v
```

Extracts all field values from WyDocs XML (using tag names as field names) and populates matching fields in the PDF. Silently skips fields that exist in XML but not PDF, or vice versa. Only fills non-empty values.

Use this for testing form mapping without a full WyDocs environment.

### Using the Skill's Python Environment

For PDF operations not covered by the scripts above, use the skill's venv directly:

```bash
~/.claude/skills/wydocs-forms/.venv/bin/python3 << 'EOF'
import pikepdf

with pikepdf.open("/path/to/form.pdf", allow_overwriting_input=True) as pdf:
    # Inspect or modify PDF structure
    if "/AcroForm" in pdf.Root:
        for field in pdf.Root.AcroForm.Fields:
            print(field.T if "/T" in field else "(no name)")
    pdf.save("/path/to/output.pdf")
EOF
```

**Available libraries:**
- `pikepdf` - Low-level PDF manipulation (form fields, structure inspection)
- `pypdf` - General PDF operations (merging, splitting, basic form work)
- `pdfplumber` - Extract text and tables from PDFs

## Workflow

1. **Identify document type** - Is this a Loan document or MSP (Member Services) document? This determines which prefix conventions to use.

2. **Extract fields** - Run `extract_fields` on the PDF to get a complete list of current field names.

3. **Read the PDF visually** to understand structure and identify:
   - Data fields (name, address, amounts, dates)
   - Signature fields
   - Checkboxes
   - Custom/manual entry fields

4. **Look up field mappings** - Use `lookup_field` to find the right WyDocs field for each form field based on its label/purpose.

5. **Check naming conventions** against the rules below

6. **Propose changes** with specific field names and reasoning

7. **Update CUNAmapping.csv** if new field mappings are needed

## Reference Data

Field dictionaries are stored locally in `~/.claude/skills/wydocs-forms/data/`:

- **Lending_Dictionary_clean.json** - Loan document fields (P_/C_/O1_ prefixes)
- **MSP_Dictionary_clean.json** - Member Services fields (A_/JN1_/JN2_ prefixes)

**Prefer using the `lookup_field` script** to search these - it's faster than reading the full files and returns ranked results. Only read the JSON directly if you need to browse all fields in a section.

## Data Field Prefixes (Quick Reference)

### Loan Documents
| Role | Prefix |
|------|--------|
| Primary Applicant | `P_` |
| Co-Applicant/Spouse | `C_` |
| Other Applicants | `O1_`, `O2_`, `O3_`... `O8_` |
| Loan-specific | `LN_` |

Note: Business forms may have many "Other" roles (O1-O8+) for guarantors, authorized persons, etc. See "Multi-Person Form Mapping" section.

### MSP (Member Services) Documents
| Role | Prefix |
|------|--------|
| Primary | `A_` |
| Joint 1-3 | `JN1_`, `JN2_`, `JN3_` |

### Custom Fields
For fields requiring manual entry (no database value): `CU_FIELD_NAME`

## Digital Signature Field Naming

### Format
`{ROLE}_SIG_{SEQUENCE}` — e.g., `PRIMARY_SIG_1`, `PRIMARY_SIG_2`

### Singular Roles (one person per document)
| Role | Usage |
|------|-------|
| `PRIMARY` | Primary borrower/applicant |
| `COBORROWER` | Co-borrower (loan forms) |
| `JOINT` | Joint owner (membership forms) |
| `LN_OFFICER` | Loan officer/CU staff |

### Indexed Roles (multiple people with data fields)
Format: `OTHER{N}_SIG_{SEQUENCE}` — e.g., `OTHER1_SIG_1`

Use for: guarantors, cosigners, collateral owners — people who have data fields on the form.

### Non-Party Signers (no data fields)
Use custom descriptive names for people signing who are NOT parties to the loan:

| Form Label | Field Name |
|------------|------------|
| Borrower Spouse (consent) | `SPOUSE_SIG_1` |
| Witness | `WITNESS_SIG_1` |
| Notary | `NOTARY_SIG_1` |

**Key rule:** Do NOT use `OTHER{N}` for non-party signers — that's reserved for parties with data fields.

### Date/Initials
- Date: append `_DATE` — `PRIMARY_SIG_1_DATE`
- Initials: replace `SIG` with `INITIALS` — `PRIMARY_INITIALS_1`

## CUNAmapping.csv

Location: `mappings/CUNAmapping.csv` in the WyDocsSupport repo

### Format
```csv
FieldName,ChangeToType,Rename,ReadOnly,NonPrintable,StampPicture,FormatCode,ValidationCode,DefaultValue,Action
```

### Key Columns
- `FieldName` - Original field name in CUNA PDF
- `Rename` - WyDocs database field name to map to
- `ChangeToType` - Set to `checkbox` to convert text field to checkbox
- `ReadOnly` - `True`/`False`
- `DefaultValue` - Value to pre-fill
- `Action` - Set to `DELETE` to remove field

### Adding New Mappings
When you encounter a CUNA field that needs mapping:
1. Look up the correct WyDocs field name in the reference files
2. Add a row: `CUNA_FIELD_NAME,,,False,False,,,,,` (minimal entry)
3. Or with rename: `CUNA_FIELD_NAME,,WYDOCS_FIELD_NAME,False,False,,,,,`

## How CUNATool Works

CUNATool applies transforms in this order:
1. **Global transforms** from CUNAmapping.csv
2. **CU-specific data** from `CUSpecificDataINF.txt` (CU name, address — sets both value AND default, marks read-only)
3. **Account-specific transforms** from `{AccountNumber}-mapping.csv` if it exists

When setting a DefaultValue, the system sets BOTH the visible field value AND the PDF default value (what the field resets to).

## Common Patterns

1. **Business forms with multiple borrowers/guarantors** - See "Multi-Person Form Mapping" below.

2. **Spouse consent fields** (Louisiana, community property) - Non-party signer, use `SPOUSE_SIG_N`

3. **Checkbox fields** - Look for "FLAG" in database field names; set `ChangeToType` to `checkbox`

4. **Signature fields with no party match** - If someone signs but has no data fields, use custom naming (WITNESS, NOTARY, SPOUSE, LANDLORD, WISCONSIN)

## Multi-Person Form Mapping (Business Loans)

**Critical:** The mapping of GUARANTOR, AUTHPERS, and AP3/AP4 to O1_, O2_, etc. is **form-specific** based on order of appearance.

### Fixed Mappings
- AP1_ → P_ (always)
- AP2_ → C_ (always, if present)

### Dynamic Mappings (order-based)
After P_ and C_, assign O1_, O2_, O3_... to remaining roles in the order they first appear on the form:

**Example - Form with AP1, AP2, G1-4:**
- AP1→P_, AP2→C_, G1→O1_, G2→O2_, G3→O3_, G4→O4_

**Example - Form with AP1, AP2, AP3, AP4, G1-4:**
- AP1→P_, AP2→C_, AP3→O1_, AP4→O2_, G1→O3_, G2→O4_, G3→O5_, G4→O6_

### Field Name Transformation
After determining prefix, also transform field suffixes:
- `_SSN` → `_TIN`
- `_PRES_ADD1` → `_PRI_ADDR_ADDRESS1`
- `_PRES_ADD2` → `_PRI_ADDR_CITYSTATEZIP`
- `_PRES_ADD3` → `_PRI_ADDR_ADDRESS2`
- `_BIRTH_DT` → `_BIRTH_DATE`

So GUARANTOR1_SSN (if G1→O3) becomes **O3_TIN**.

### Signature Field Alignment
Data prefix and signature prefix must match:
- P_ data → PRIMARY_SIG_1
- C_ data → COBORROWER_SIG_1
- O1_ data → OTHER1_SIG_1
- O3_ data → OTHER3_SIG_1

## Form Review Checklist

- [ ] Document type identified (Loan vs MSP)
- [ ] All data fields have appropriate mappings or `CU_` prefix
- [ ] Signature fields follow naming conventions
- [ ] Date fields exist for signatures that need them
- [ ] Non-party signers use custom names (not `OTHER{N}`)
- [ ] No duplicate field names
- [ ] Checkbox fields properly configured

## Full Documentation

See `docs/wydocs-form-mapping-guide.md` in the WyDocsSupport repository for complete user documentation.
