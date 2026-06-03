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

# Authentication state
AUTH_REQUIRED=0
AUTH_CREDENTIALS=""

# Restore terminal on exit/interrupt
trap 'stty icanon echo </dev/tty 2>/dev/null' EXIT INT TERM

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

# Check if authentication is required
echo -ne "${CYAN}Checking authentication requirements...${NC}"
start_loading

# Use nc with a small timeout and capture output
# Use a temporary file to capture response
temp_file=$(mktemp)
(echo -e "CREATE UUID\n" | nc -w 2 "$HOST" "$PORT" 2>/dev/null | head -c 100) > "$temp_file" 2>/dev/null &
nc_pid=$!
sleep 0.1
kill $nc_pid 2>/dev/null
wait $nc_pid 2>/dev/null

test_response=$(cat "$temp_file" 2>/dev/null)
rm -f "$temp_file"
stop_loading

# Check if we got AUTH_FAILED response
if [[ "$test_response" == *"AUTH_FAILED"* ]]; then
    # Authentication is required
    echo -ne "\b${YELLOW}⚠${NC}"
    echo -e "\n${YELLOW}${BOLD}⚠ Authentication required${NC}"
    AUTH_REQUIRED=1
elif [[ -n "$test_response" ]]; then
    # Got a valid response, no auth required
    echo -ne "\b${GREEN}✓${NC}"
    echo -e "\n${GREEN}${BOLD}✓ No authentication required${NC}"
    AUTH_REQUIRED=0
else
    # No response or timeout - could not determine
    echo -ne "\b${YELLOW}?${NC}"
    echo -e "\n${YELLOW}${BOLD}? Could not determine auth status${NC}"
    
    # Ask user if they want to try with auth
    echo -ne "${CYAN}Do you want to try with authentication? (y/n): ${NC}"
    read -r try_auth
    if [[ "$try_auth" == "y" || "$try_auth" == "Y" ]]; then
        AUTH_REQUIRED=1
    else
        AUTH_REQUIRED=0
    fi
fi
echo ""

# Prompt for credentials if authentication is required
if [ $AUTH_REQUIRED -eq 1 ]; then
    echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}${BOLD}                    AUTHENTICATION${NC}"
    echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
    
    # Get username
    echo -ne "${CYAN}Enter username: ${NC}"
    read -r username
    
    # Get password (hidden input)
    echo -ne "${CYAN}Enter password: ${NC}"
    read -r -s password
    echo
    
    # Store credentials in session memory
    AUTH_CREDENTIALS="$username:$password"
    
    # Test authentication
    echo -ne "${CYAN}Testing authentication...${NC}"
    start_loading
    
    # Use nc with proper handling
    temp_file=$(mktemp)
    (echo -e "AUTH $AUTH_CREDENTIALS\nCREATE UUID\n" | nc -w 2 "$HOST" "$PORT" 2>/dev/null | head -c 100) > "$temp_file" 2>/dev/null &
    nc_pid=$!
    sleep 0.1
    kill $nc_pid 2>/dev/null
    wait $nc_pid 2>/dev/null
    
    auth_test_response=$(cat "$temp_file" 2>/dev/null)
    rm -f "$temp_file"
    stop_loading
    
    if [[ "$auth_test_response" == *"AUTH_FAILED"* ]] || [[ -z "$auth_test_response" ]]; then
        echo -ne "\b${RED}✗${NC}"
        echo -e "\n${RED}${BOLD}✗ Authentication failed${NC}"
        echo -e "${YELLOW}Please check your credentials and try again.${NC}"
        echo ""
        exit 1
    else
        echo -ne "\b${GREEN}✓${NC}"
        echo -e "\n${GREEN}${BOLD}✓ Authentication successful${NC}"
        echo ""
    fi
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
    # Build prompt with $'...' syntax for escape codes
    PROMPT=$'\033[0;32m\033[1mmixql\033[0m\033[0;36m\033[1m ❯ \033[0m'
    read -e -p "$PROMPT" QUERY
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
        echo ""
        echo -e "${YELLOW}${BOLD}  Hashing & Encoding${NC}"
        echo -e "${CYAN}  SELECT SHA256(:input) AS hash${NC}      - SHA-256 hash (recommended)"
        echo -e "${CYAN}  SELECT SHA512(:input) AS hash${NC}      - SHA-512 hash"
        echo -e "${CYAN}  SELECT SHA1(:input) AS hash${NC}        - SHA-1 hash (legacy)"
        echo -e "${CYAN}  SELECT MD5(:input) AS hash${NC}         - MD5 hash (legacy)"
        echo -e "${CYAN}  SELECT BASE64_ENCODE(:input) AS hash${NC} - Base64 encode"
        echo -e "${CYAN}  SELECT HMAC(:key, :msg) AS hash${NC}    - HMAC-SHA256 keyed hash"
        echo -e "${CYAN}  SELECT ... AS hash UPPERCASE${NC}       - Uppercase output"
        echo ""
        echo -e "${YELLOW}${BOLD}  Password Hashing (Argon2)${NC}"
        echo -e "${CYAN}  SELECT ARGON2(:input) AS hash${NC}      - Argon2id password hash"
        echo -e "${CYAN}  SELECT ARGON2_VERIFY(:hash, :pw) AS hash${NC} - Verify password"
        echo ""
        echo -e "${YELLOW}${BOLD}  Encryption (AES-256-CBC)${NC}"
        echo -e "${CYAN}  SELECT ENC(:input) AS hash${NC}         - Encrypt (server key)"
        echo -e "${CYAN}  SELECT ENC(:input) KEY mykey AS hash${NC} - Encrypt (custom key)"
        echo -e "${CYAN}  SELECT ENC(:input) SALT :s1,:s2 AS hash${NC} - Layered encryption"
        echo -e "${CYAN}  SELECT ENC(:input) PEPPER :p1,:p2 AS hash${NC} - Interleave peppers"
        echo -e "${CYAN}  SELECT ENC(:input) KEY :k SALT :s PEPPER :p AS hash${NC} - Full"
        echo ""
        echo -e "${YELLOW}${BOLD}  Decryption (AES-256-CBC)${NC}"
        echo -e "${CYAN}  SELECT DEC(:input) AS hash${NC}         - Decrypt (server key)"
        echo -e "${CYAN}  SELECT DEC(:input) KEY mykey AS hash${NC} - Decrypt (custom key)"
        echo -e "${CYAN}  SELECT DEC(:input) KEY :k SALT :s PEPPER :p AS hash${NC} - Full"
        echo ""
        echo -e "${YELLOW}${BOLD}  Encryption (AES-256-GCM - Authenticated)${NC}"
        echo -e "${CYAN}  SELECT ENC_GCM(:input) AS hash${NC}     - GCM encrypt (recommended)"
        echo -e "${CYAN}  SELECT ENC_GCM(:input) KEY mykey AS hash${NC} - GCM custom key"
        echo -e "${CYAN}  SELECT ENC_GCM(:input) KEY :k SALT :s PEPPER :p AS hash${NC} - Full"
        echo ""
        echo -e "${YELLOW}${BOLD}  Decryption (AES-256-GCM - Authenticated)${NC}"
        echo -e "${CYAN}  SELECT DEC_GCM(:input) AS hash${NC}     - GCM decrypt"
        echo -e "${CYAN}  SELECT DEC_GCM(:input) KEY mykey AS hash${NC} - GCM custom key"
        echo -e "${CYAN}  SELECT DEC_GCM(:input) KEY :k SALT :s PEPPER :p AS hash${NC} - Full"
        echo ""
        echo -e "${YELLOW}${BOLD}  Generators${NC}"
        echo -e "${CYAN}  CREATE UUID${NC}                        - Generate UUID"
        echo -e "${CYAN}  CREATE SALT${NC}                        - Generate cryptographic salt"
        echo -e "${CYAN}  CREATE SALT LIMIT 5 LENGTH 32${NC}      - Multiple salts"
        echo -e "${CYAN}  CREATE SALT SHA${NC}                    - SHA-1 hashed salt"
        echo -e "${CYAN}  CREATE KEY${NC}                         - Generate encryption key"
        echo -e "${CYAN}  CREATE KEY LIMIT 5${NC}                 - Multiple keys"
        echo ""
        echo -e "${YELLOW}${BOLD}  Functions${NC}"
        echo -e "${CYAN}  CONCAT(a, b, ...)${NC}                  - Concatenate values"
        echo -e "${CYAN}  NOW()${NC}                              - Current Unix timestamp"
        echo ""
        echo -e "${YELLOW}${BOLD}  Storage${NC}"
        echo -e "${CYAN}  SELECT ... STORE AS name${NC}           - Store query for reuse"
        echo -e "${CYAN}  STORE LIST${NC}                         - List stored queries"
        echo -e "${CYAN}  STORE SELECT name${NC}                  - View stored query"
        echo -e "${CYAN}  STORE USE name${NC}                     - Execute stored query"
        echo -e "${CYAN}  STORE DELETE name${NC}                  - Delete stored query"
        echo ""
        echo -e "${YELLOW}${BOLD}  CLI${NC}"
        echo -e "${CYAN}  exit${NC}                               - Exit the CLI"
        echo -e "${CYAN}  help, ?${NC}                            - Show this help"
        echo ""
        echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
        echo ""
        continue
    fi
    
    # Validate empty query
    if [[ -z "$QUERY" ]]; then
        continue
    fi

    # Find all placeholders (e.g., :param) - preserve order, keep unique
    PLACEHOLDERS=()
    while read -r placeholder; do
        if [[ ! " ${PLACEHOLDERS[@]} " =~ " ${placeholder} " ]]; then
            PLACEHOLDERS+=("$placeholder")
        fi
    done < <(grep -oE ":\w+" <<< "$QUERY")
    PARAM_VALUES=()

    # Check if this is any STORE command variant
    # STORE commands should not prompt for parameter values
    # Note: STORE USE is handled separately as it executes stored queries
    IS_STORE_COMMAND=0
    if [[ "$QUERY" =~ STORE[[:space:]]+(AS|LIST|SELECT|DELETE) ]] || [[ "$QUERY" =~ ^STORE[[:space:]]+(LIST|SELECT|DELETE) ]]; then
        IS_STORE_COMMAND=1
    fi

    # Special handling for STORE USE - stored queries may need parameters
    IS_STORE_USE=0
    if [[ "$QUERY" =~ ^STORE[[:space:]]+USE[[:space:]]+ ]]; then
        IS_STORE_USE=1
    fi

    # If placeholders exist and it's not a STORE command, prompt the user for each value
    if [ ${#PLACEHOLDERS[@]} -gt 0 ] && [ $IS_STORE_COMMAND -eq 0 ]; then
        echo -e "${PURPLE}${BOLD}┌─[PARAMETERS]${NC}"
        for placeholder in "${PLACEHOLDERS[@]}"; do
            clean_placeholder="${placeholder#:}"
            echo -ne "${PURPLE}${BOLD}│ ${NC}${CYAN}Enter value for \"$clean_placeholder\": ${NC}"
            # Use stty raw mode + perl to bypass terminal line buffer limit
            # Strips line breaks and spaces from pasted text (concatenates into one continuous string)
            stty -icanon min 1 time 0 -echo </dev/tty 2>/dev/null
            value=$(perl -e '
                use IO::Select;
                open(my $tty, "<", "/dev/tty") or die;
                my $buf = "";
                my $sel = IO::Select->new($tty);
                my $first_char = 1;
                my $is_paste = 0;
                while(sysread($tty, my $c, 1)) {
                    if ($first_char) {
                        $first_char = 0;
                        $is_paste = $sel->can_read(0.01) ? 1 : 0;
                    }
                    if (!$is_paste && ($c eq "\n" || $c eq "\r")) {
                        last;
                    }
                    if ($is_paste && ($c eq "\n" || $c eq "\r" || $c eq " ")) {
                        last unless $sel->can_read(0.05);
                        next;
                    }
                    if (ord($c) == 127 || ord($c) == 8) {
                        if (length($buf) > 0) {
                            $buf = substr($buf, 0, -1);
                            print STDERR "\b \b";
                        }
                        next;
                    }
                    $buf .= $c;
                    print STDERR $c;
                }
                print $buf;
            ' 2>/dev/tty)
            stty icanon echo </dev/tty 2>/dev/null
            echo
            PARAM_VALUES+=("$value")
        done
        echo -e "${PURPLE}${BOLD}└────────────────${NC}"
    fi

    # STORE USE command - get stored query first, then prompt for its parameters
    if [ $IS_STORE_USE -eq 1 ]; then
        # Extract store name from STORE USE <name>
        STORE_NAME=$(echo "$QUERY" | awk '{print $3}')
        
        if [ -n "$STORE_NAME" ]; then
            # First, get the stored query definition
            echo -e "${PURPLE}${BOLD}┌─[GETTING STORED QUERY]${NC}"
            echo -ne "${PURPLE}${BOLD}│ ${NC}${CYAN}Fetching stored query '$STORE_NAME'...${NC}"
            
            # Send STORE SELECT <name> to get the query (NO trailing newline based on your example)
            # Prepend AUTH command if authentication is required
            store_select_input="STORE SELECT $STORE_NAME"
            if [ $AUTH_REQUIRED -eq 1 ] && [ -n "$AUTH_CREDENTIALS" ]; then
                store_select_input="AUTH $AUTH_CREDENTIALS\n$store_select_input"
            fi
            
            stored_query_response=$(echo -e "$store_select_input" | nc $HOST $PORT 2>/dev/null)
            stored_query_response=$(echo "$stored_query_response" | sed 's/[[:space:]]*$//')
            
            if [ -n "$stored_query_response" ] && [[ ! "$stored_query_response" == *"ERROR"* ]] && [[ ! "$stored_query_response" == *"not found"* ]] && [[ ! "$stored_query_response" == *"Query not found"* ]]; then
                echo -e "\b${GREEN}✓${NC}"
                
                # Extract parameters from the stored query - preserve order, keep unique
                STORED_PLACEHOLDERS=()
                while read -r placeholder; do
                    if [[ ! " ${STORED_PLACEHOLDERS[@]} " =~ " ${placeholder} " ]]; then
                        STORED_PLACEHOLDERS+=("$placeholder")
                    fi
                done < <(grep -oE ":\w+" <<< "$stored_query_response")
                
                if [ ${#STORED_PLACEHOLDERS[@]} -gt 0 ]; then
                    echo -e "\n${PURPLE}${BOLD}┌─[PARAMETERS FOR STORED QUERY]${NC}"
                    for placeholder in "${STORED_PLACEHOLDERS[@]}"; do
                        clean_placeholder="${placeholder#:}"
                        echo -ne "${PURPLE}${BOLD}│ ${NC}${CYAN}Enter value for \"$clean_placeholder\": ${NC}"
                        stty -icanon min 1 time 0 -echo </dev/tty 2>/dev/null
                        value=$(perl -e '
                            use IO::Select;
                            open(my $tty, "<", "/dev/tty") or die;
                            my $buf = "";
                            my $sel = IO::Select->new($tty);
                            my $first_char = 1;
                            my $is_paste = 0;
                            while(sysread($tty, my $c, 1)) {
                                if ($first_char) {
                                    $first_char = 0;
                                    $is_paste = $sel->can_read(0.01) ? 1 : 0;
                                }
                                if (!$is_paste && ($c eq "\n" || $c eq "\r")) {
                                    last;
                                }
                                if ($is_paste && ($c eq "\n" || $c eq "\r" || $c eq " ")) {
                                    last unless $sel->can_read(0.05);
                                    next;
                                }
                                if (ord($c) == 127 || ord($c) == 8) {
                                    if (length($buf) > 0) {
                                        $buf = substr($buf, 0, -1);
                                        print STDERR "\b \b";
                                    }
                                    next;
                                }
                                $buf .= $c;
                                print STDERR $c;
                            }
                            print $buf;
                        ' 2>/dev/tty)
                        stty icanon echo </dev/tty 2>/dev/null
                        echo
                        PARAM_VALUES+=("$value")
                    done
                    echo -e "${PURPLE}${BOLD}└────────────────${NC}"
                fi
            else
                echo -e "\b${RED}✗${NC}"
                echo -e "${PURPLE}${BOLD}│ ${NC}${RED}Could not retrieve stored query${NC}"
                echo -e "${PURPLE}${BOLD}└────────────────${NC}"
                # Still continue to try STORE USE
            fi
        fi
    fi

    # Send the query to the MixQL service via TCP and get the response with timeout
    echo -e "${GREEN}${BOLD}┌─[QUERY EXECUTION]${NC}"
    echo -ne "${GREEN}${BOLD}│ ${NC}${CYAN}Executing query...${NC}"
    start_loading
    
    # Build the multi-line input: query + parameters on separate lines
    if [ ${#PARAM_VALUES[@]} -gt 0 ]; then
        # Build the input with query first, then each parameter on new line
        INPUT="$QUERY"
        for param_value in "${PARAM_VALUES[@]}"; do
            INPUT="$INPUT\n$param_value"
        done
    else
        INPUT="$QUERY"
    fi
    
    # Prepend AUTH command if authentication is required
    if [ $AUTH_REQUIRED -eq 1 ] && [ -n "$AUTH_CREDENTIALS" ]; then
        INPUT="AUTH $AUTH_CREDENTIALS\n$INPUT"
    fi
    
    if command -v timeout &> /dev/null; then
        response=$(echo -e "$INPUT" | timeout 5 nc $HOST $PORT 2>/dev/null)
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
        response=$(echo -e "$INPUT" | nc $HOST $PORT 2>/dev/null)
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