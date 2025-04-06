#!/bin/bash

echo ""
echo "--------------"
echo ""
echo "███╗   ███╗██╗██╗  ██╗ ██████╗ ██╗        "  
echo "████╗ ████║██║╚██╗██╔╝██╔═══██╗██║        "
echo "██╔████╔██║██║ ╚███╔╝ ██║   ██║██║        "
echo "██║╚██╔╝██║██║ ██╔██╗ ██║▄▄ ██║██║        "
echo "██║ ╚═╝ ██║██║██╔╝ ██╗╚██████╔╝███████╗   "
echo "╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   "
echo ""                                       
echo "// -- Powered by:"
echo ""
echo "┏┓┏┓┳┓┳┏┓┳┏┳┓┓┏ "
echo "┗┓┣ ┃┃┃┃ ┃ ┃ ┗┫ "
echo "┗┛┗┛┛┗┻┗┛┻ ┻ ┗┛ "
echo ""               
echo "// --> https://senicity.com "
echo "// -- "
echo ""
echo "------------"
echo "This is the MixQL Command Line Interface for making queries to the server."
echo "------------"

# Defaults
HOST="localhost"
PORT="7272"

while getopts "h:p:" opt; do
  case "$opt" in
    h) HOST="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    \?) echo "Usage: $0 [-h host] [-p port]"
        exit 1 ;;
  esac
done

echo "------------"
echo "Running on: $HOST:$PORT"
echo "------------"
echo "------------"
echo "Type your MixQL query (type 'exit' to quit):"
echo "------------"
echo ""

while true; do
    # Prompt for SQL input
    echo -n "mixql> "
    read QUERY
    
    # Exit condition
    if [[ "$QUERY" == "exit" ]]; then
        break
    fi

    # Find all placeholders (e.g., :param)
    PLACEHOLDERS=($(grep -oE ":\w+" <<< "$QUERY" | sort -u))

    # If placeholders exist, prompt the user for each value
    echo ""
    for placeholder in "${PLACEHOLDERS[@]}"; do
        clean_placeholder="${placeholder#:}"
        echo -n "Enter value for \"$clean_placeholder\": "
        read value
        QUERY="${QUERY//${placeholder}/$value}"
    done

    # Send the query to the MixQL service via TCP and get the response
    response=$(echo "$QUERY" | nc $HOST $PORT)

    # Output the response from the server
    echo ""
    if [[ "$response" == *"ERROR"* ]]; then
        echo -e "\033[31m❌ Error:\033[0m\n$response"
    else
        echo -e "\033[32m✅ Success:\033[0m\n$response"
    fi
    echo ""

done