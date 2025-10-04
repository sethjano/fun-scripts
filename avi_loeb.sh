#!/bin/bash

# avi_loeb.sh - Satirical Commentary Generator
# Generates over-the-top cosmic commentary in the style of Avi Loeb
# For entertainment purposes only - not affiliated with the actual Avi Loeb

# Color codes for dramatic effect
BOLD='\033[1m'
ITALIC='\033[3m'
RESET='\033[0m'

# Get topic from command line or prompt
if [ -z "$1" ]; then
    echo "Enter a topic for cosmic commentary:"
    read -r TOPIC
else
    TOPIC="$*"
fi

# Loeb-ism opening phrases
OPENINGS=(
    "As I've argued extensively in my latest preprint"
    "In a paper I recently submitted to the Astrophysical Journal"
    "Contrary to what the establishment would have you believe"
    "My colleagues at Harvard and I have been investigating"
    "The data clearly shows, though many refuse to acknowledge"
    "In my forthcoming book, I discuss how"
    "As any open-minded scientist would recognize"
    "The scientific orthodoxy dismisses this, but"
    "Galileo faced similar resistance when he proposed"
    "Our team's rigorous analysis suggests"
)

# Loeb-ism middle phrases
MIDDLES=(
    "exhibits characteristics inconsistent with natural terrestrial objects"
    "shows anomalous behavior that defies conventional explanations"
    "presents a unique opportunity to search for technosignatures"
    "could be evidence of extraterrestrial intelligence, if we're willing to look"
    "deserves serious scientific scrutiny, not dismissive skepticism"
    "represents precisely the kind of phenomenon we should investigate"
    "challenges our assumptions about what's possible in the universe"
    "may hold clues to advanced civilizations beyond Earth"
    "demonstrates features suggestive of artificial design"
    "warrants investigation with the Galileo Project's instrumentation"
)

# Loeb-ism closing phrases
CLOSINGS=(
    "The establishment prefers comfortable ignorance to uncomfortable truth."
    "As Galileo knew, orthodoxy often blinds us to extraordinary discoveries."
    "We must follow the evidence wherever it leads, however unsettling."
    "History will judge harshly those who refuse to examine the data."
    "The scientific method demands we consider all possibilities, not just familiar ones."
    "Extraordinary claims require extraordinary evidence - and here it is."
    "Our cosmic humility should compel us to investigate, not dismiss."
    "The universe is under no obligation to conform to our expectations."
    "Future generations will wonder why we hesitated to ask obvious questions."
    "This is precisely why we need more funding for SETI and related research."
)

# Loeb-ism technical terms
TERMS=(
    "technosignatures"
    "interstellar origin"
    "non-gravitational acceleration"
    "unusual light curve"
    "anomalous trajectory"
    "Oumuamua-like properties"
    "pancake-shaped morphology"
    "solar radiation pressure"
    "artificial construction"
    "advanced propulsion"
)

# Loeb-ism references
REFERENCES=(
    "Oumuamua"
    "the Galileo Project"
    "interstellar objects"
    "extraterrestrial civilizations"
    "alien artifacts"
    "technosignatures in our Solar System"
    "advanced extraterrestrial technology"
    "the search for cosmic neighbors"
    "non-natural phenomena"
    "artifacts of technological origin"
)

# Random selection helper
random_element() {
    local array=("$@")
    local rand_index=$((RANDOM % ${#array[@]}))
    echo "${array[$rand_index]}"
}

# Generate the commentary
echo ""
echo -e "${BOLD}=== Avi Loeb Commentary Generator ===${RESET}"
echo -e "${ITALIC}Topic: ${TOPIC}${RESET}"
echo ""
echo "---"
echo ""

# Opening
OPENING=$(random_element "${OPENINGS[@]}")
echo "${OPENING}, the ${TOPIC}"

# Middle with technical term
MIDDLE=$(random_element "${MIDDLES[@]}")
TERM=$(random_element "${TERMS[@]}")
echo "${MIDDLE}. The presence of ${TERM}"

# Connection to cosmic themes
REFERENCE=$(random_element "${REFERENCES[@]}")
echo "bears striking similarity to ${REFERENCE}."

# Add extra Loeb flavor
EXTRA=$((RANDOM % 3))
case $EXTRA in
    0)
        echo "Some will call this speculation, but is it speculation to follow the data?"
        ;;
    1)
        echo "My critics say I'm being provocative, but I'm simply being scientific."
        ;;
    2)
        echo "The astronomical community's resistance to this idea speaks volumes."
        ;;
esac

# Closing
CLOSING=$(random_element "${CLOSINGS[@]}")
echo ""
echo "${CLOSING}"

# Signature
echo ""
echo "---"
echo -e "${ITALIC}Commentary generated $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

# Optional: Generate a second paragraph for variety
if [ $((RANDOM % 2)) -eq 0 ]; then
    echo "Furthermore, the ${TOPIC} demonstrates precisely the kind of"
    echo "$(random_element "${TERMS[@]}") that we should expect from"
    echo "$(random_element "${REFERENCES[@]}")."
    echo "Yet the mainstream scientific establishment continues to ignore"
    echo "what should be obvious to any unbiased observer."
    echo ""
fi

# Easter egg: Extremely unlikely bonus commentary
if [ $((RANDOM % 100)) -eq 42 ]; then
    echo ""
    echo "🛸 BONUS INSIGHT 🛸"
    echo ""
    echo "In fact, I would argue that the ${TOPIC} may well be our"
    echo "first confirmed detection of extraterrestrial technology."
    echo "I've already submitted three papers on this to Nature."
    echo ""
fi

echo "---"
echo ""
echo "Disclaimer: This is satire. For actual Avi Loeb commentary,"
echo "see his real scientific work and popular writing."
echo ""
