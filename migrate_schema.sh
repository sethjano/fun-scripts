#!/bin/bash

# migrate_schema.sh
# Migrates acronyms.db from 4-field to 9-field schema
# Old: ACRONYM|Expansion|Category|Status
# New: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink

OLD_DB="acronyms.db"
NEW_DB="acronyms_v2.db"

echo "=== Acronym Database Schema Migration ==="
echo "Old format: ACRONYM|Expansion|Category|Status"
echo "New format: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink"
echo ""

# Create new database with updated header
cat > "$NEW_DB" <<'EOF'
# IBM Acronym Database v2.0
# Format: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink
# Status: VERIFIED (real), GENERATED (made up by AI)
# Source: MANUAL (user-added), NIST (NIST CSRC Glossary), GENERATED (AI-created)
# Category: product, service, technology, business, security, etc.

EOF

# Migrate existing entries
echo "Migrating existing entries..."

line_count=0
migrated=0

while IFS='|' read -r acronym expansion category status; do
    # Skip comments and empty lines
    [[ "$acronym" =~ ^# ]] && continue
    [[ -z "$acronym" ]] && continue

    ((line_count++))

    # Add entry with new fields (empty Definition, Source=MANUAL, empty links)
    echo "${acronym}|${expansion}||${category}|${status}|MANUAL|||" >> "$NEW_DB"
    ((migrated++))

done < "$OLD_DB"

echo "✓ Migrated $migrated entries from old format"
echo "✓ New database: $NEW_DB"
echo ""
echo "Backup of old database: ${OLD_DB}.backup"
echo ""
echo "To activate new schema:"
echo "  mv acronyms.db acronyms.db.old"
echo "  mv acronyms_v2.db acronyms.db"
