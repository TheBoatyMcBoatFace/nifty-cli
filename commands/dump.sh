# commands/dump.sh
#!/bin/bash

# Determine if the script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Please run this script using: source dump"
    exit 0  # Use exit instead of return
else
    # Existing logic to unset variables
    if [ -f .env ]; then
        unset_count=0

        # Read each line from the .env file
        while IFS= read -r line || [[ -n "$line" ]]; do

            # Ignore comments, empty lines, and lines not in KEY=VALUE format
            if [[ -n "$line" && "$line" != "#"* && "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.+$ ]]; then
                var_name=$(echo "$line" | sed 's/=.*//')

                # Check if the variable exists in a way that works in both Bash and Zsh
                if eval '[ ! -z "${'$var_name'+x}" ]'; then
                    # Unset the variable if it exists
                    unset "$var_name"
                    unset_count=$((unset_count + 1))
                    echo "Unsetting $var_name"  # Optional for debugging purposes
                fi
            fi
        done < .env

        echo "---------------------------------"
        echo "$unset_count variables unset."
    else
        echo ".env file not found in the current directory."
    fi
fi
