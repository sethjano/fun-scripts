#!/bin/bash

# import_nist_fast.sh
# Fast one-time import of NIST CSRC glossary into acronyms.db
# Uses jq for all processing to avoid slow bash loops

NIST_JSON="glossary-export.json"
DB_FILE="acronyms.db"
TEMP_IMPORT="nist_import_temp.txt"

echo "=== NIST CSRC Glossary Import (Fast) ==="
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required for JSON parsing"
    echo "   Install: brew install jq"
    exit 1
fi

# Check if NIST JSON exists
if [ ! -f "$NIST_JSON" ]; then
    echo "❌ Error: $NIST_JSON not found"
    exit 1
fi

echo "📊 Processing NIST glossary with jq..."

# Use jq to do all the heavy lifting
jq -r '
.parentTerms[] |
select(.abbrSyn) |
select(.term | length <= 10) |
select(.term | test("<em>|<i>|<strong>") | not) |
{
  term: .term,
  link: .link,
  expansions: .abbrSyn,
  definitions: .definitions
} |
.expansions[] as $exp |
{
  acronym: .term,
  expansion: $exp.text,
  definition: (if .definitions then .definitions[0].text else "" end),
  sourcePub: (if .definitions then .definitions[0].sources[0].text else "" end),
  sourceLink: (if .definitions then .definitions[0].sources[0].link else "" end),
  nistLink: .link
} |
# Filter out bad expansions
select(.expansion | test("^(abstraction|specific|quasi|address|[0-9]+)$") | not) |
select(.expansion | test("<em>|<i>|<strong>") | not) |
# Skip single lowercase words
select(.expansion | test("^[a-z]+$") | not) |
# Determine category
. + {
  category: (
    if (.expansion | test("Officer|Manager|Director|Chief|Administrator")) then "role"
    elif (.expansion | test("Protocol|Interface|Algorithm|Encryption|Authentication|Security|Cryptographic")) then "security"
    elif (.expansion | test("System|Software|Hardware|Device|Computer|Server|Network")) then "technology"
    elif (.expansion | test("Standard|Specification")) then "standard"
    else "technology"
    end
  )
} |
# Clean definition (remove newlines, extra spaces)
.definition |= (gsub("\n"; " ") | gsub("  +"; " ")) |
# Output in pipe-delimited format
[.acronym, .expansion, .definition, .category, "VERIFIED", "NIST", .sourcePub, .sourceLink, .nistLink] |
@tsv
' "$NIST_JSON" | tr '\t' '|' > "$TEMP_IMPORT"

imported=$(wc -l < "$TEMP_IMPORT" | tr -d ' ')

echo "✓ Processing complete!"
echo ""
echo "📈 Import Statistics:"
echo "   Entries ready for import: $imported"
echo ""

# Show sample of what will be imported
echo "📋 Sample imports (first 10):"
head -10 "$TEMP_IMPORT" | while IFS='|' read -r acr exp def cat stat src spub slink nlink; do
    echo "   $acr → $exp [$cat]"
done
echo ""

# Ask for confirmation
echo "⚠️  This will add $imported entries to $DB_FILE"
echo -n "Continue? (y/n): "
read -r confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Import cancelled"
    rm "$TEMP_IMPORT"
    exit 0
fi

# Append to database
cat "$TEMP_IMPORT" >> "$DB_FILE"
rm "$TEMP_IMPORT"

echo ""
echo "✅ Import complete! Added $imported NIST entries to database"
echo ""

# Show new database stats
total_entries=$(grep -c '^[A-Z0-9]' "$DB_FILE")
manual_entries=$(grep -c '|MANUAL|' "$DB_FILE")
nist_entries=$(grep -c '|NIST|' "$DB_FILE")

echo "📊 Database Statistics:"
echo "   Total entries: $total_entries"
echo "   Manual entries: $manual_entries"
echo "   NIST entries: $nist_entries"
