#!/bin/bash

# import_nist.sh
# One-time import of NIST CSRC glossary into acronyms.db
# Filters bad data, extracts multiple expansions, captures definitions

NIST_JSON="glossary-export.json"
DB_FILE="acronyms.db"
TEMP_IMPORT="nist_import_temp.txt"

# Data quality filters
BAD_PATTERNS="^(abstraction|specific|quasi|address|[0-9]+|[a-z]+)$"

echo "=== NIST CSRC Glossary Import ==="
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

echo "📊 Analyzing NIST glossary..."
total_terms=$(jq '.totalRecords' "$NIST_JSON")
echo "   Total NIST terms: $total_terms"

# Extract acronyms with filters
echo ""
echo "🔍 Extracting acronyms with quality filters..."
echo "   Filters:"
echo "   - Acronym length ≤ 10 characters"
echo "   - Skip HTML tags (<em>, <i>)"
echo "   - Skip single generic words"
echo "   - Skip obvious bad mappings"
echo ""

> "$TEMP_IMPORT"  # Clear temp file

imported=0
skipped=0
bad_expansions=0

# Process each term
while read -r term; do
    # Skip if term is too long
    if [ ${#term} -gt 10 ]; then
        ((skipped++))
        continue
    fi

    # Skip HTML artifacts
    if [[ "$term" =~ \<em\>|\<i\>|\<strong\> ]]; then
        ((skipped++))
        continue
    fi

    # Get NIST glossary link
    nist_link=$(jq -r --arg term "$term" '.parentTerms[] | select(.term == $term) | .link' "$NIST_JSON")

    # Get all expansions (abbrSyn array)
    expansions=$(jq -r --arg term "$term" '.parentTerms[] | select(.term == $term) | .abbrSyn[]? | .text' "$NIST_JSON")

    # Skip if no expansions
    if [ -z "$expansions" ]; then
        ((skipped++))
        continue
    fi

    # Get all definitions with sources
    definitions=$(jq -c --arg term "$term" '.parentTerms[] | select(.term == $term) | .definitions[]?' "$NIST_JSON")

    # Process each expansion
    while IFS= read -r expansion; do
        # Skip empty
        [ -z "$expansion" ] && continue

        # Skip bad patterns
        if echo "$expansion" | grep -qiE "$BAD_PATTERNS"; then
            ((bad_expansions++))
            continue
        fi

        # Skip HTML tags in expansion
        if [[ "$expansion" =~ \<em\>|\<i\>|\<strong\> ]]; then
            ((bad_expansions++))
            continue
        fi

        # Determine category based on expansion text
        category="technology"
        if [[ "$expansion" =~ (Officer|Manager|Director|Chief|Administrator) ]]; then
            category="role"
        elif [[ "$expansion" =~ (Protocol|Interface|Algorithm|Encryption|Authentication|Security) ]]; then
            category="security"
        elif [[ "$expansion" =~ (System|Software|Hardware|Device|Computer) ]]; then
            category="technology"
        elif [[ "$expansion" =~ (Standard|Specification) ]]; then
            category="standard"
        fi

        # Get first definition and source for this expansion
        definition=""
        source_pub=""
        source_link=""

        if [ ! -z "$definitions" ]; then
            # Extract first definition text (clean up formatting)
            definition=$(echo "$definitions" | head -1 | jq -r '.text' | tr '\n' ' ' | sed 's/  */ /g')

            # Extract source publication
            source_pub=$(echo "$definitions" | head -1 | jq -r '.sources[0]?.text // ""')

            # Extract source link
            source_link=$(echo "$definitions" | head -1 | jq -r '.sources[0]?.link // ""')
        fi

        # Build database entry
        # Format: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink
        echo "${term}|${expansion}|${definition}|${category}|VERIFIED|NIST|${source_pub}|${source_link}|${nist_link}" >> "$TEMP_IMPORT"
        ((imported++))

    done <<< "$expansions"

done < <(jq -r '.parentTerms[] | select(.abbrSyn) | .term' "$NIST_JSON")

echo "✓ Processing complete!"
echo ""
echo "📈 Import Statistics:"
echo "   Entries imported: $imported"
echo "   Terms skipped: $skipped"
echo "   Bad expansions filtered: $bad_expansions"
echo ""

# Show sample of what will be imported
echo "📋 Sample imports (first 5):"
head -5 "$TEMP_IMPORT" | while IFS='|' read -r acr exp def cat stat src spub slink nlink; do
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
total_entries=$(grep -c '^[A-Z]' "$DB_FILE")
echo "📊 Database now contains $total_entries total entries"
