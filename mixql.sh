#!/bin/bash

# Check if output is to a terminal
if [[ -t 1 ]]; then
    # Color definitions for terminal
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    # No colors for non-terminal output
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    BOLD=''
    NC=''
fi

# Show loading animation (run in background)
start_loading() {
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # Run animation in background
    (
        while true; do
            for i in $(seq 0 9); do
                echo -ne "\b${spinstr:$i:1}" >&2
                sleep $delay
            done
        done
    ) &
    LOADING_PID=$!
}

# Stop loading animation
stop_loading() {
    kill $LOADING_PID 2>/dev/null
    wait $LOADING_PID 2>/dev/null
}

# Clean, simple header with animation
echo ""
echo -ne "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}\n"
echo -ne "${PURPLE}║${NC}                                                              ${PURPLE}║${NC}\n"
echo -ne "${PURPLE}║${NC}                    "
for char in M I X Q L; do
    echo -ne "${WHITE}${BOLD}$char${NC} "
    sleep 0.1
done
echo -ne "                                ${PURPLE}║${NC}\n"
echo -ne "${PURPLE}║${NC}               ${CYAN}Command Line Interface${NC}                         ${PURPLE}║${NC}\n"
echo -ne "${PURPLE}║${NC}                                                              ${PURPLE}║${NC}\n"
echo -ne "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
echo ""

# ASCII art
echo -e "${WHITE}███╗   ███╗██╗██╗  ██╗ ██████╗ ██╗${NC}"
echo -e "${WHITE}████╗ ████║██║╚██╗██╔╝██╔═══██╗██║${NC}"
echo -e "${WHITE}██╔████╔██║██║ ╚███╔╝ ██║   ██║██║${NC}"
echo -e "${WHITE}██║╚██╔╝██║██║ ██╔██╗ ██║▄▄ ██║██║${NC}"
echo -e "${WHITE}██║ ╚═╝ ██║██║██╔╝ ██╗╚██████╔╝███████╗${NC}"
echo -e "${WHITE}╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝${NC}"
echo ""

# Subtitles
echo -e "${CYAN}Secure Data Operations${NC}"
echo -e "${WHITE}Hashing • Salting • Encryption${NC}"
echo ""

# Defaults
HOST="localhost"
PORT="7272"

# Check if netcat is available
if ! command -v nc &> /dev/null; then
    echo -e "\033[31m❌ netcat (nc) is not installed\033[0m"
    echo "Please install netcat to use the MixQL CLI."
    exit 1
fi

while getopts "h:p:" opt; do
  case "$opt" in
    h) HOST="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    \?) echo "Usage: $0 [-h host] [-p port]"
        exit 1 ;;
  esac
done

echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}${BOLD}                    CONNECTION STATUS${NC}"
echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo ""

# Show connection test
echo -ne "${CYAN}Testing connection to ${WHITE}$HOST:$PORT${CYAN}...${NC}"
start_loading

# Test connection before entering REPL loop
if nc -z "$HOST" "$PORT" 2>/dev/null; then
    stop_loading
    echo -ne "\b${GREEN}✓${NC}"
    echo -e "\n${GREEN}${BOLD}✓ Connected to: $HOST:$PORT${NC}"
    echo ""
else
    stop_loading
    echo -ne "\b${RED}✗${NC}"
    echo -e "\n${RED}${BOLD}✗ Connection failed: $HOST:$PORT${NC}"
    echo -e "${YELLOW}Please ensure the MixQL server is running.${NC}"
    echo ""
    exit 1
fi

echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}${BOLD}                    INTERACTIVE REPL${NC}"
echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo -e "${CYAN}Type MixQL queries below (type 'exit' to quit, 'help' for help)${NC}"
echo ""

# Initialize history file
HISTORY_FILE="$HOME/.mixql_history"
touch "$HISTORY_FILE"

while true; do
    # Prompt for SQL input with readline support
    echo -ne "${GREEN}${BOLD}mixql${NC}${CYAN}${BOLD} ❯ ${NC}"
    read -e QUERY
    # Save to history
    echo "$QUERY" >> "$HISTORY_FILE"
    
    # Exit condition
    if [[ "$QUERY" == "exit" ]]; then
        echo -e "${YELLOW}Exiting MixQL CLI. Goodbye!${NC}"
        echo ""
        break
    fi
    
    # Help command
    if [[ "$QUERY" == "help" || "$QUERY" == "?" ]]; then
        echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${WHITE}${BOLD}                    AVAILABLE COMMANDS${NC}"
        echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${CYAN}SELECT ... AS hash${NC}     - Execute a hash query"
        echo -e "${CYAN}CREATE UUID${NC}            - Generate UUID"
        echo -e "${CYAN}CREATE SALT${NC}            - Generate cryptographic salt"
        echo -e "${CYAN}CREATE KEY${NC}             - Generate encryption key"
        echo -e "${CYAN}STORE ...${NC}              - Store/retrieve queries"
        echo -e "${CYAN}exit${NC}                   - Exit the CLI"
        echo -e "${CYAN}help, ?${NC}                - Show this help"
        echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo ""
        continue
    fi
    
    # Validate empty query
    if [[ -z "$QUERY" ]]; then
        continue
    fi

    # Find all placeholders (e.g., :param)
    PLACEHOLDERS=($(grep -oE ":\w+" <<< "$QUERY" | sort -u))

    # If placeholders exist, prompt the user for each value
    if [ ${#PLACEHOLDERS[@]} -gt 0 ]; then
        echo -e "${PURPLE}${BOLD}┌─[PARAMETERS]${NC}"
        for placeholder in "${PLACEHOLDERS[@]}"; do
            clean_placeholder="${placeholder#:}"
            echo -ne "${PURPLE}${BOLD}│ ${NC}${CYAN}Enter value for \"$clean_placeholder\": ${NC}"
            read value
            QUERY="${QUERY//${placeholder}/$value}"
        done
        echo -e "${PURPLE}${BOLD}└────────────────${NC}"
    fi

    # Send the query to the MixQL service via TCP and get the response with timeout
    echo -e "${GREEN}${BOLD}┌─[QUERY EXECUTION]${NC}"
    echo -ne "${GREEN}${BOLD}│ ${NC}${CYAN}Executing query...${NC}"
    start_loading
    
    if command -v timeout &> /dev/null; then
        response=$(echo "$QUERY" | timeout 5 nc $HOST $PORT 2>/dev/null)
        exit_code=$?
        stop_loading
        
        # Check if we got a response (not empty) instead of just nc exit code
        if [ -n "$response" ]; then
            echo -ne "\b${GREEN}✓${NC}"
        elif [ $exit_code -eq 124 ]; then
            echo -ne "\b${RED}✗${NC}"
            echo -e "\n${GREEN}${BOLD}└────────────────${NC}"
            echo -e "${YELLOW}${BOLD}⏰ TIMEOUT${NC}${YELLOW}: No response from server after 5 seconds${NC}"
            echo ""
            continue
        else
            echo -ne "\b${RED}✗${NC}"
        fi
    else
        # Fallback without timeout
        response=$(echo "$QUERY" | nc $HOST $PORT 2>/dev/null)
        stop_loading
        # Check if we got a response (not empty) instead of just nc exit code
        if [ -n "$response" ]; then
            echo -ne "\b${GREEN}✓${NC}"
        else
            echo -ne "\b${RED}✗${NC}"
        fi
    fi

    # Output the response from the server
    echo -e "\n${GREEN}${BOLD}└────────────────${NC}"
    echo ""
    
    if [[ "$response" == *"ERROR"* ]]; then
        echo -e "${RED}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${WHITE}${BOLD}                         ERROR DETECTED${NC}"
        echo -e "${RED}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${RED}$response${NC}"
    else
        echo -e "${GREEN}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${WHITE}${BOLD}                         SUCCESS!${NC}"
        echo -e "${GREEN}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo -e "${WHITE}$response${NC}"
    fi
    
    echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
    echo ""

done