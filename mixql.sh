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

    if [[ "$QUERY" =~ ^CREATE\ SALT\ LIMIT\ ([a-zA-Z]) ]]; then
         echo ""
         echo -e "\033[31m❌ Error:\033[0m\nLimit cannot be that value (possibly a letter, not integer) for CREATE SALT"
         echo ""
        continue
    fi

    # Check if the query is a CREATE SALT LIMIT statement
    if [[ "$QUERY" =~ ^CREATE\ SALT\ LIMIT\ ([0-9]+) ]]; then
        limit="${BASH_REMATCH[1]}"
        limit=$(echo "$limit" | xargs)

        if [[ -z "$limit" ]]; then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nLimit cannot be that value (possibly a letter, not integer) for CREATE SALT"
            echo ""
            continue
        fi

        if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nMust be an integer for CREATE SALT"
            echo ""
            continue
        fi
        
        # Check if the limit is a valid positive integer and within range
        if (( limit < 1 || limit > 100 )); then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nInvalid limit value provided for CREATE SALT"
            echo ""
            continue
        fi
    fi

    if [[ "$QUERY" =~ ^CREATE\ KEY\ LIMIT\ ([a-zA-Z]) ]]; then
         echo ""
         echo -e "\033[31m❌ Error:\033[0m\nLimit cannot be that value (possibly a letter, not integer) for CREATE KEY"
         echo ""
        continue
    fi

    if [[ "$QUERY" =~ ^CREATE\ KEY\ LIMIT\ ([0-9]+) ]]; then

        limit="${BASH_REMATCH[1]}"
        limit=$(echo "$limit" | xargs)

        if [[ -z "$limit" ]]; then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nLimit cannot be that value (possibly a letter, not integer) for CREATE KEY"
            echo ""
            continue
        fi

        if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nMust be an integer for CREATE KEY"
            echo ""
            continue
        fi
        
        # Check if the limit is a valid positive integer and within range
        if (( limit < 1 || limit > 100 )); then
            echo ""
            echo -e "\033[31m❌ Error:\033[0m\nInvalid limit value provided for CREATE KEY"
            echo ""
            continue
        fi
    fi

    # Check if the query is a SELECT statement
    if [[ "$QUERY" == *"SELECT"* ]]; then
        # Ask for the placeholder value (for the '?' placeholder)
        echo ""
        echo -e "\033[34mEnter string to be hashed:\033[0m "
        read PLACEHOLDER_VALUE

        # Replace '?' with the provided placeholder value in the query
        FINAL_QUERY=$(echo "$QUERY" | sed "s/?/$PLACEHOLDER_VALUE/")
    else
        # No placeholder needed for non-SELECT queries
        FINAL_QUERY="$QUERY"
    fi

    # Send the query to the MixQL service via TCP and get the response
    response=$(echo "$FINAL_QUERY" | nc $HOST $PORT)

    # Output the response from the server
    echo ""
    if [[ "$response" == *"ERROR"* ]]; then
        echo -e "\033[31m❌ Error:\033[0m\n$response"
    else
        echo -e "\033[32m✅ Success:\033[0m\n$response"
    fi
    echo ""

done