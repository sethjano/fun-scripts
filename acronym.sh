#!/bin/bash

# acronym.sh - Tech Acronym Decoder & Generator
# V3: Enhanced with NIST CSRC glossary data, definitions, source links, and fuzzy search
# Looks up real acronyms from 4000+ NIST terms, generates funny alternatives
# Compatible with bash 3.2+ (macOS default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/acronyms.db"

# Color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
RESET='\033[0m'

# Database schema v2.0
# ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink

# Escape regex metacharacters for safe grep usage
escape_regex() {
    echo "$1" | sed 's/[]\.*^$[]/\\&/g'
}

# Word banks organized by first letter (mix of jargon + technical, ~2:1 funny-to-serious)
WORDS_A="Agile Advanced Automated Abstract Adaptive Actionable Alignment Architecture Analytics API Asynchronous Abstraction"
WORDS_B="Blockchain Business Buzzword Best-practice Bandwidth Bureaucratic Baseline Backend Broker Bridge Bootstrap"
WORDS_C="Cloud Containerized Continuous Collaborative Cross-functional Capability Compliance Cybersecurity Catalyst Cache Controller Convergence"
WORDS_D="Digital Distributed Disruptive Data-driven DevOps Dashboard Dynamic Database Deployment Deliverable Dependency"
WORDS_E="Enterprise Encrypted Event-driven Ecosystem Efficiency Enablement Executive Elastic Endpoint Engineering Escalation"
WORDS_F="Framework Flexible Fundamental Fault-tolerant Frontend FinOps Fabric Firewall Factory Failover Function"
WORDS_G="Global Governance Gateway Granular Grid Graphical Generator GUI Gigabit"
WORDS_H="Hybrid Horizontal Hierarchical High-availability Holistic Hardware Hub Hypervisor Hyperscale Handler"
WORDS_I="Intelligent Integrated Infrastructure Innovative Interface Innovation Initiative Immutable Implementation Interoperability Identity"
WORDS_J="Just-in-time Jargon JavaScript JSON Jira Journey Jumpstart Junction"
WORDS_K="Key Kubernetes Knowledge Kernel Kiosk Kickoff"
WORDS_L="Legacy Leveraged Latency Leadership Lifecycle Lightweight Load-balancer Logic Layer Localhost"
WORDS_M="Microservice Managed Modernized Multi-cloud Middleware Mission-critical Metrics Mainframe Matrix Migration Monitoring Modular"
WORDS_N="Next-generation Network Normalized Node Native Namespace Notification Negotiation"
WORDS_O="Optimized Orchestrated Operational Observability Obfuscated Object-oriented Onboarding Offline Orchestrator Overhead"
WORDS_P="Platform Paradigm Pivot Protocol Proprietary Process Pipeline Productivity Provisioning Performance Proxy Perspective"
WORDS_Q="Quantum Quality Queryable Queue Quotient Quarterly Qualification"
WORDS_R="Resilient Responsive Real-time Regulatory Revolutionary Robotic Redundant Repository Runtime Reorg Registry"
WORDS_S="Scalable Secure Strategic Synergy Stakeholder System Service Software Solution Serverless Synchronization Storage Schema"
WORDS_T="Transformation Tactical Transaction Technical Throughput Tokenized Transparent Thread Telemetry Ticket Template"
WORDS_U="Unified Universal Upstream Usability Utility Ubiquitous Unlocked Update Uptime"
WORDS_V="Virtual Vertical Virtualized Validated Velocity Vendor Visibility Volume Versioning VPN"
WORDS_W="Workflow Workstream Waterfall Warehouse Widget Wizard Workspace Workload"
WORDS_X="eXtreme eXtensible XML eXperience eXecution eXchange eXperimental"
WORDS_Y="YAML Yield Yesterday's"
WORDS_Z="Zero-trust Zonal Zone Zenith Zettabyte"

# Get random word starting with specific letter
get_word_for_letter() {
    local letter=$(echo "$1" | tr '[:lower:]' '[:upper:]')

    # If it's a number, just return it
    if [[ "$letter" =~ ^[0-9]$ ]]; then
        echo "$letter"
        return
    fi

    # Get words for this letter using variable indirection
    local var_name="WORDS_${letter}"
    local words="${!var_name}"

    if [ -z "$words" ]; then
        # Fallback for missing letters
        case "$letter" in
            Q) echo "Quantum" ;;
            X) echo "eXtreme" ;;
            Z) echo "Zero-trust" ;;
            *) echo "${letter}ybernetic" ;;
        esac
        return
    fi

    # Convert to array and pick random
    local word_array=($words)
    local rand_index=$((RANDOM % ${#word_array[@]}))
    echo "${word_array[$rand_index]}"
}

# Get hardcoded funny definitions
get_hardcoded_funny() {
    local acronym=$(echo "$1" | tr '[:lower:]' '[:upper:]')

    case "$acronym" in
        TPF) echo "Three-Pizza Friday|Time-wasting Project Fiasco|Totally Perplexing Framework" ;;
        IBM) echo "Incredibly Boring Meetings|I've Been Migrated|Impossibly Big Mainframe" ;;
        API) echo "Another Pointless Interface|Always Partially Implemented|Annoying Programming Issue" ;;
        ELA) echo "Endless Legal Anxiety|Everyone Loses Anyway|Expensive Licensing Arrangement" ;;
        AWS) echo "Always Wait Silently|Actually Works Sometimes|Acronyms Within Services" ;;
        CPU) echo "Coffee Processing Unit|Continually Puzzled User|Completely Pointless Upgrade" ;;
        RAM) echo "Really Annoying Memory|Random Access Maybe|Rarely Adequate Megabytes" ;;
        SQL) echo "Slow Query Language|Still Quite Lengthy|Suspiciously Quick Lie" ;;
        CEO) echo "Chief Excuse Officer|Constantly Explaining Overspending|Conference Eats Only" ;;
        CFO) echo "Chief Frowning Officer|Constantly Fighting Overhead|Can't Find Optimism" ;;
        AI) echo "Actually Intern|Almost Intelligent|Absolutely Inconsistent" ;;
        ML) echo "Maybe Learning|Mostly Lying|Meeting Loop" ;;
        URL) echo "Utterly Random Link|Usually Ridiculously Long|Unreadable Resource Locator" ;;
        PDF) echo "Practically Defective Format|Please Don't Forward|Permanently Damaged File" ;;
        SLA) echo "Sometimes Late Anyway|Seriously Lame Agreement|Suspiciously Low Accountability" ;;
        ROI) echo "Return On Ignorance|Really Optimistic Interpretation|Rarely Observed Improvements" ;;
        KPI) echo "Key Pointless Indicator|Keeping People Insecure|Kafkaesque Performance Index" ;;
        OKR) echo "Obviously Keeping Records|Overly Komplex Requirements|Obstinately Krushing Realism" ;;
        *) echo "" ;;
    esac
}

# Generate expansion matching letter pattern
generate_expansion() {
    local acronym="$1"
    local length=${#acronym}
    local result=""

    for ((i=0; i<length; i++)); do
        local char="${acronym:$i:1}"
        local word=$(get_word_for_letter "$char")
        result+="$word"
        [ $i -lt $((length-1)) ] && result+=" "
    done

    echo "$result"
}

# Look up acronym in database (returns all matching rows)
# Case-insensitive search, but preserves original case in results
lookup_acronym() {
    local acronym="$1"  # Preserve original case
    local safe_acronym=$(escape_regex "$acronym")
    grep -i "^${safe_acronym}|" "$DB_FILE" 2>/dev/null
}

# Fuzzy search - find similar acronyms (case-insensitive)
fuzzy_search() {
    local query="$1"  # Preserve case for display
    local max_suggestions=5
    local safe_query=$(escape_regex "$query")

    # Strategy 1: Case-insensitive partial match
    local partial=$(grep -i "^${safe_query}" "$DB_FILE" 2>/dev/null | cut -d'|' -f1 | sort -u | head -n $max_suggestions)

    # Strategy 2: Prefix match (first 2-3 chars)
    if [ -z "$partial" ] && [ ${#query} -ge 2 ]; then
        local prefix="${query:0:2}"
        local safe_prefix=$(escape_regex "$prefix")
        partial=$(grep -i "^${safe_prefix}" "$DB_FILE" 2>/dev/null | cut -d'|' -f1 | sort -u | head -n $max_suggestions)
    fi

    # Strategy 3: Similar length acronyms (±1 character)
    if [ -z "$partial" ]; then
        local len=${#query}
        local min_len=$((len - 1))
        local max_len=$((len + 1))
        partial=$(awk -F'|' -v min=$min_len -v max=$max_len 'length($1) >= min && length($1) <= max && $1 !~ /^#/ {print $1}' "$DB_FILE" | sort -u | head -n $max_suggestions)
    fi

    echo "$partial"
}

# Display fuzzy search suggestions with interactive selection
show_suggestions() {
    local query="$1"
    local suggestions=$(fuzzy_search "$query")

    if [ ! -z "$suggestions" ]; then
        echo -e "${YELLOW}❓ '$query' not found. Did you mean one of these?${RESET}"
        echo ""

        # Store suggestions in array for selection
        local suggestion_array=()
        local count=1
        while IFS= read -r suggestion; do
            [ -z "$suggestion" ] && continue

            # Get first expansion for this acronym
            local safe_suggestion=$(escape_regex "$suggestion")
            local expansion=$(grep -i "^${safe_suggestion}|" "$DB_FILE" | head -1 | cut -d'|' -f2)
            echo -e "  ${count}. ${CYAN}${suggestion}${RESET} - ${expansion}"
            suggestion_array+=("$suggestion")
            ((count++))
        done <<< "$suggestions"

        echo ""
        echo -n "Select (1-${#suggestion_array[@]}) or Enter to generate new: "
        read -r choice

        # If user selected a number, look up that acronym
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#suggestion_array[@]}" ]; then
            local selected="${suggestion_array[$((choice-1))]}"
            lookup_and_display "$selected"
            exit 0
        fi

        return 0
    fi

    return 1
}

# Save new acronym to database (v2 schema)
save_acronym() {
    local acronym="$1"
    local expansion="$2"
    local status="$3"  # GENERATED or VERIFIED

    # Format: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink
    echo "${acronym}|${expansion}||generated|${status}|GENERATED|||" >> "$DB_FILE"
}

# Remove acronym from database (helper function) - case-insensitive
remove_acronym() {
    local acronym="$1"
    local safe_acronym=$(escape_regex "$acronym")
    local temp_file="${DB_FILE}.tmp"
    grep -iv "^${safe_acronym}|" "$DB_FILE" > "$temp_file"
    mv "$temp_file" "$DB_FILE"
}

# Add a new verified acronym (v2 schema) - preserves case
add_verified() {
    local acronym="$1"  # Preserve case!
    local expansion="$2"
    local category="${3:-other}"
    local force="${4:-no}"

    # Check if already exists (case-insensitive)
    local existing=$(lookup_acronym "$acronym")

    if [ ! -z "$existing" ]; then
        # Check if it's a GENERATED entry
        if echo "$existing" | grep -q "|GENERATED|"; then
            # Auto-replace GENERATED entries
            remove_acronym "$acronym"
            echo "${acronym}|${expansion}||${category}|VERIFIED|MANUAL|||" >> "$DB_FILE"
            echo -e "${GREEN}✓ Replaced generated entry: $acronym is now verified${RESET}"
            echo -e "  ${CYAN}$expansion${RESET}"
            return 0
        elif [ "$force" = "force" ]; then
            # Force replace ALL entries for this acronym
            remove_acronym "$acronym"
            echo "${acronym}|${expansion}||${category}|VERIFIED|MANUAL|||" >> "$DB_FILE"
            echo -e "${GREEN}✓ Forcibly replaced all entries: $acronym${RESET}"
            echo -e "  ${CYAN}$expansion${RESET}"
            return 0
        else
            # Reject replacement of existing entries without force
            local count=$(echo "$existing" | wc -l | tr -d ' ')
            echo -e "${YELLOW}❌ Error: $acronym already has $count definition(s)${RESET}"
            echo -e "   Use ${BOLD}--force${RESET} flag to replace all entries"
            echo -e "   Or use ${BOLD}promote${RESET} command to upgrade"
            return 1
        fi
    fi

    # New entry - preserve case
    echo "${acronym}|${expansion}||${category}|VERIFIED|MANUAL|||" >> "$DB_FILE"
    echo -e "${GREEN}✓ Added: $acronym = $expansion${RESET}"
}

# Promote a GENERATED entry to VERIFIED (explicit upgrade) - preserves case
promote_acronym() {
    local acronym="$1"  # Preserve case!
    local expansion="$2"
    local category="${3:-other}"

    # Check if exists (case-insensitive)
    local existing=$(lookup_acronym "$acronym")

    if [ -z "$existing" ]; then
        echo -e "${YELLOW}⚠ $acronym not found in database${RESET}"
        echo -e "   Adding as new verified entry..."
        echo "${acronym}|${expansion}||${category}|VERIFIED|MANUAL|||" >> "$DB_FILE"
        echo -e "${GREEN}✓ Added: $acronym = $expansion${RESET}"
        return 0
    fi

    # Check status - only promote GENERATED entries
    if echo "$existing" | grep -q "|GENERATED|"; then
        # Promote from GENERATED to VERIFIED
        remove_acronym "$acronym"
        echo "${acronym}|${expansion}||${category}|VERIFIED|MANUAL|||" >> "$DB_FILE"
        echo -e "${GREEN}✓ Promoted: $acronym upgraded to verified${RESET}"
        echo -e "  ${CYAN}$expansion${RESET}"
    else
        echo -e "${YELLOW}⚠ $acronym is already VERIFIED${RESET}"
        echo -e "   Use ${BOLD}add --force${RESET} to replace"
    fi
}

# Display a single definition entry with formatting
display_definition() {
    local num="$1"
    local expansion="$2"
    local definition="$3"
    local category="$4"
    local status="$5"
    local source="$6"
    local source_pub="$7"
    local source_link="$8"
    local nist_link="$9"

    echo -e "${BOLD}📖 Definition $num: ${CYAN}${expansion}${RESET} ${BLUE}[$category]${RESET}"

    # Show definition if available
    if [ ! -z "$definition" ]; then
        # Word wrap definition at 70 chars
        echo "$definition" | fold -s -w 70 | while IFS= read -r line; do
            echo "   $line"
        done
        echo ""
    fi

    # Show source information
    if [ "$source" = "NIST" ]; then
        if [ ! -z "$source_pub" ]; then
            echo -e "   ${MAGENTA}📚 Source: $source_pub${RESET}"
            if [ ! -z "$source_link" ]; then
                echo -e "      ${CYAN}→ $source_link${RESET}"
            fi
        fi
        if [ ! -z "$nist_link" ]; then
            echo -e "   ${MAGENTA}🔗 NIST Glossary: ${CYAN}$nist_link${RESET}"
        fi
    elif [ "$source" = "MANUAL" ]; then
        echo -e "   ${MAGENTA}👤 Source: User-added${RESET}"
    elif [ "$source" = "GENERATED" ]; then
        echo -e "   ${YELLOW}🤖 Source: AI-generated${RESET}"
    fi

    echo ""
}

# Main lookup and display function
lookup_and_display() {
    local acronym="$1"  # Preserve case!

    echo ""
    echo -e "${BOLD}=== Acronym Decoder ===${RESET}"
    echo -e "Looking up: ${CYAN}$acronym${RESET}"
    echo ""

    # Look up in database (case-insensitive)
    local results=$(lookup_acronym "$acronym")

    if [ ! -z "$results" ]; then
        # Count results
        local count=$(echo "$results" | wc -l | tr -d ' ')

        if [ $count -eq 1 ]; then
            echo -e "${GREEN}✓ Found in database:${RESET}"
        else
            echo -e "${GREEN}✓ Found in database ($count definitions):${RESET}"
        fi
        echo ""

        # Display each definition
        local num=1
        while IFS='|' read -r acr exp def cat stat src spub slink nlink; do
            display_definition "$num" "$exp" "$def" "$cat" "$stat" "$src" "$spub" "$slink" "$nlink"
            ((num++))
        done <<< "$results"

    else
        # Not found - show suggestions
        if show_suggestions "$acronym"; then
            echo -e "Or continue to generate a new definition..."
            echo ""
        else
            echo -e "${YELLOW}❌ Not found in database${RESET}"
            echo ""
        fi

        # Generate and save a new expansion
        echo -e "${BLUE}Generating technical expansion...${RESET}"
        local generated=$(generate_expansion "$acronym")
        save_acronym "$acronym" "$generated" "GENERATED"
        echo -e "  ${CYAN}$generated${RESET} ${YELLOW}(auto-generated, saved to DB)${RESET}"
        echo ""
    fi

    # Always show funny alternatives
    echo -e "${MAGENTA}🎭 Humorous interpretations:${RESET}"

    # Check for hardcoded funnies first
    local hardcoded=$(get_hardcoded_funny "$acronym")

    if [ ! -z "$hardcoded" ]; then
        # Use hardcoded funny definitions
        local num=1
        echo "$hardcoded" | tr '|' '\n' | while IFS= read -r funny; do
            echo -e "  ${num}. ${funny} 😄"
            ((num++))
        done
    else
        # Generate 3 random funny alternatives
        for i in 1 2 3; do
            local funny=$(generate_expansion "$acronym")
            echo -e "  ${i}. ${funny} 😄"
        done
    fi

    echo ""
}

# List all acronyms (with optional filter)
list_acronyms() {
    local filter="$1"

    echo ""
    echo -e "${BOLD}=== Acronym Database ===${RESET}"

    if [ ! -z "$filter" ]; then
        echo -e "Filter: ${CYAN}$filter${RESET}"
        local safe_filter=$(escape_regex "$filter")
        local results=$(grep -i "$safe_filter" "$DB_FILE" | grep -v "^#")
    else
        local results=$(grep -v "^#" "$DB_FILE")
    fi

    local count=$(echo "$results" | grep -c "^[A-Z0-9]")
    echo -e "Total entries: ${GREEN}$count${RESET}"
    echo ""

    # Group by acronym and show count
    echo "$results" | cut -d'|' -f1,2,6 | sort -u | while IFS='|' read -r acr exp src; do
        local defs=$(echo "$results" | grep "^${acr}|" | wc -l | tr -d ' ')
        if [ $defs -gt 1 ]; then
            echo -e "${CYAN}$acr${RESET} - $exp ${YELLOW}(+$((defs-1)) more)${RESET} ${BLUE}[$src]${RESET}"
        else
            echo -e "${CYAN}$acr${RESET} - $exp ${BLUE}[$src]${RESET}"
        fi
    done | head -50

    if [ $count -gt 50 ]; then
        echo ""
        echo -e "${YELLOW}... showing first 50 of $count entries${RESET}"
        echo -e "Use: ${BOLD}./ibm_acronym.sh list <filter>${RESET} to narrow results"
    fi

    echo ""
}

# Show database statistics
show_stats() {
    echo ""
    echo -e "${BOLD}=== Database Statistics ===${RESET}"
    echo ""

    local total=$(grep -c "^[A-Z0-9]" "$DB_FILE")
    local manual=$(grep -c "|MANUAL|" "$DB_FILE")
    local nist=$(grep -c "|NIST|" "$DB_FILE")
    local generated=$(grep -c "|GENERATED|" "$DB_FILE")
    local unique=$(cut -d'|' -f1 "$DB_FILE" | grep "^[A-Z0-9]" | sort -u | wc -l | tr -d ' ')

    echo -e "Total entries:        ${GREEN}$total${RESET}"
    echo -e "Unique acronyms:      ${GREEN}$unique${RESET}"
    echo -e "Manual entries:       ${CYAN}$manual${RESET}"
    echo -e "NIST entries:         ${BLUE}$nist${RESET}"
    echo -e "AI-generated:         ${YELLOW}$generated${RESET}"
    echo ""

    # Show most common acronyms (with multiple definitions)
    echo -e "${BOLD}Acronyms with most definitions:${RESET}"
    cut -d'|' -f1 "$DB_FILE" | grep "^[A-Z0-9]" | sort | uniq -c | sort -rn | head -5 | while read count acr; do
        echo -e "  ${CYAN}$acr${RESET}: $count definitions"
    done
    echo ""
}

# Show help
show_help() {
    cat << 'EOF'
Tech Acronym Decoder & Generator v3.0

USAGE:
  ./acronym.sh <acronym>              Look up or generate acronym
  ./acronym.sh list [filter]          List all acronyms (optional filter)
  ./acronym.sh stats                  Show database statistics
  ./acronym.sh add <ACRONYM> "Expansion" [category]
                                      Add verified acronym
  ./acronym.sh add --force <ACRONYM> "Expansion" [category]
                                      Force replace all existing entries
  ./acronym.sh promote <ACRONYM> "Expansion" [category]
                                      Upgrade AI-generated to verified

EXAMPLES:
  ./acronym.sh API                    # Look up API
  ./acronym.sh 2FA                    # Look up 2FA (NIST data)
  ./acronym.sh list security          # List security-related acronyms
  ./acronym.sh stats                  # Show database stats
  ./acronym.sh add TPF "Transaction Processing Facility" product
  ./acronym.sh promote DEMO "Demonstration Environment" tech

FEATURES:
  • 4000+ verified acronyms from NIST CSRC glossary
  • Definitions with source publication links
  • Fuzzy search suggestions for typos
  • Auto-generates technical expansions for unknown acronyms
  • Creates funny alternatives for every lookup
  • Learns new acronyms (saves to database)
  • Supports multiple definitions per acronym

CATEGORIES:
  product, service, technology, security, business, role, standard, etc.

DATABASE:
  Location: acronyms.db
  Format: ACRONYM|Expansion|Definition|Category|Status|Source|SourcePub|SourceLink|NISTLink
  Sources: MANUAL (user-added), NIST (NIST CSRC), GENERATED (AI-created)

EOF
}

# Main script logic
main() {
    # Check if database exists
    if [ ! -f "$DB_FILE" ]; then
        echo -e "${RED}❌ Error: Database file not found: $DB_FILE${RESET}"
        exit 1
    fi

    # Parse command
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command="$1"

    case "$command" in
        help|--help|-h)
            show_help
            ;;
        list)
            list_acronyms "$2"
            ;;
        stats)
            show_stats
            ;;
        add)
            if [ "$2" = "--force" ]; then
                add_verified "$3" "$4" "$5" "force"
            else
                add_verified "$2" "$3" "$4"
            fi
            ;;
        promote)
            promote_acronym "$2" "$3" "$4"
            ;;
        *)
            lookup_and_display "$1"
            ;;
    esac
}

main "$@"
