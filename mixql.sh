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

    # Ask for the placeholder value (for the '?' placeholder)
    echo ""
    echo -e "\033[34mEnter string to be hashed:\033[0m "
    read PLACEHOLDER_VALUE

    # Replace '?' with the provided placeholder value in the query
    FINAL_QUERY=$(echo "$QUERY" | sed "s/?/$PLACEHOLDER_VALUE/")

    # Send the query to the MixQL service via TCP and get the response
    response=$(echo "$FINAL_QUERY" | nc $HOST $PORT)

    # Output the response from the server
    echo ""
    echo -e "\033[32mResponse:\033[0m $response"
    echo ""

done