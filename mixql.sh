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
TLS_ENABLED=0
TLS_OPTION_SET=0

usage() {
    echo "Usage: $0 [-h host] [-p port] [-t|--tls]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST   MixQL hostname (default: localhost)"
    echo "  -p, --port PORT   MixQL port (default: 7272)"
    echo "  -t, --tls         Use TLS when connecting to MixQL"
    echo "      --no-tls      Use plain TCP (default)"
    echo ""
    echo "TLS mode uses ncat when available, or openssl as a fallback."
}

# Parse command-line options. Plain TCP remains the default behavior.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            if [[ -z "${2:-}" ]]; then
                echo "Missing value for $1" >&2
                usage >&2
                exit 2
            fi
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            if [[ -z "${2:-}" ]]; then
                echo "Missing value for $1" >&2
                usage >&2
                exit 2
            fi
            PORT="$2"
            shift 2
            ;;
        -t|--tls)
            TLS_ENABLED=1
            shift
            ;;
        --no-tls)
            TLS_ENABLED=0
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# Authentication state
AUTH_REQUIRED=0
AUTH_CREDENTIALS=""

# Restore terminal on exit/interrupt
trap 'stty icanon echo </dev/tty 2>/dev/null' EXIT INT TERM

# Select the transport without changing the existing plain-TCP path.
if [ "$TLS_ENABLED" -eq 1 ]; then
    if command -v ncat &> /dev/null; then
        TLS_BACKEND="ncat"
        MIXQL_NETCAT=(ncat --ssl --ssl-verify --ssl-servername "$HOST")
        TRANSPORT="TLS via ncat --ssl (certificate verification enabled)"
    elif command -v openssl &> /dev/null; then
        TLS_BACKEND="openssl"
        MIXQL_NETCAT=(
            openssl s_client
            -quiet
            -verify_return_error
            -verify_hostname "$HOST"
            -servername "$HOST"
            -connect "$HOST:$PORT"
        )
        MIXQL_TLS_CHECK=(
            openssl s_client
            -brief
            -verify_return_error
            -verify_hostname "$HOST"
            -servername "$HOST"
            -connect "$HOST:$PORT"
        )
        TRANSPORT="TLS via openssl s_client (certificate verification enabled)"
    else
        echo -e "${RED}❌ TLS mode requires ncat or openssl, but neither is available.${NC}"
        echo "Install ncat (usually included with the nmap package), install openssl, or omit --tls."
        exit 1
    fi
else
    if ! command -v nc &> /dev/null; then
        echo -e "${RED}❌ netcat (nc) is not installed.${NC}"
        echo "Please install netcat to use the MixQL CLI."
        exit 1
    fi
    TLS_BACKEND="plain"
    MIXQL_NETCAT=(nc)
    TRANSPORT="plain TCP via nc"
fi

# Keep the command shape compatible with both netcat and openssl.
if [ "$TLS_BACKEND" = "openssl" ]; then
    MIXQL_PROBE=("${MIXQL_NETCAT[@]}")
    MIXQL_QUERY=("${MIXQL_NETCAT[@]}")
else
    MIXQL_PROBE=("${MIXQL_NETCAT[@]}" -w 2 "$HOST" "$PORT")
    MIXQL_QUERY=("${MIXQL_NETCAT[@]}" "$HOST" "$PORT")
fi

# Send a short startup probe and wait for a response. The fallback keeps
# working on macOS systems that do not provide the timeout command.
probe_mixql() {
    local payload="$1"
    local probe_file
    local probe_pid

    if command -v timeout &> /dev/null; then
        printf '%b' "$payload" |
            timeout 5 "${MIXQL_PROBE[@]}" 2>/dev/null |
            head -c 100
        return
    fi

    probe_file=$(mktemp)
    (
        printf '%b' "$payload" |
            "${MIXQL_PROBE[@]}" 2>/dev/null |
            head -c 100
    ) > "$probe_file" 2>/dev/null &
    probe_pid=$!

    # Allow time for a remote TLS handshake before stopping the probe.
    for _ in {1..20}; do
        if [ -s "$probe_file" ]; then
            break
        fi
        sleep 0.1
    done

    kill "$probe_pid" 2>/dev/null
    wait "$probe_pid" 2>/dev/null
    cat "$probe_file" 2>/dev/null
    rm -f "$probe_file"
}

echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}${BOLD}                    CONNECTION STATUS${NC}"
echo -e "${PURPLE}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo ""

# Show the selected endpoint and transport before testing the connection.
echo -e "${CYAN}Host:${NC} $HOST"
echo -e "${CYAN}Port:${NC} $PORT"
echo -e "${CYAN}Transport:${NC} $TRANSPORT"
echo ""

# Show connection test
echo -ne "${CYAN}Testing connection to ${WHITE}$HOST:$PORT${CYAN}...${NC}"
start_loading

# Test connection before entering REPL loop
if [ "$TLS_BACKEND" = "openssl" ]; then
    # Complete a TLS handshake without consuming the CLI's stdin.
    if "${MIXQL_TLS_CHECK[@]}" </dev/null >/dev/null 2>/dev/null; then
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
elif "${MIXQL_NETCAT[@]}" -z "$HOST" "$PORT" 2>/dev/null; then
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

test_response=$(probe_mixql "CREATE UUID\\n")
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
    
    auth_test_response=$(probe_mixql "AUTH $AUTH_CREDENTIALS\\nCREATE UUID\\n")
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
        echo -e "${CYAN}  Startup: -t, --tls${NC}                 - Use TLS with ncat or openssl"
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
            
            stored_query_response=$(echo -e "$store_select_input" | "${MIXQL_QUERY[@]}" 2>/dev/null)
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
        response=$(echo -e "$INPUT" | timeout 5 "${MIXQL_QUERY[@]}" 2>/dev/null)
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
        response=$(echo -e "$INPUT" | "${MIXQL_QUERY[@]}" 2>/dev/null)
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