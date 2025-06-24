# commands/load.sh
#!/bin/bash

# Check if the script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Please run this script using: source load"
    exit 1
else
    # Check if the .env file exists in the current directory
    if [ -f .env ]; then
        set_count=0  # Tracks new variables being set
        update_count=0  # Tracks existing variables being updated

        # Read each line
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Ignore comments, empty lines, and lines not in KEY=VALUE format
            if [[ -n "$line" && "$line" != "#"* && "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.+$ ]]; then
                var_name=$(echo "$line" | cut -d '=' -f 1)
                var_value=$(echo "$line" | cut -d '=' -f 2-)

                # Check if variable is already set and compare values
                current_value=$(eval echo \$$var_name)

                if [ -n "$current_value" ]; then
                    if [[ "$current_value" != "$var_value" ]]; then
                        # Count as an update
                        update_count=$((update_count + 1))
                        echo "Updating: $var_name"
                    fi
                else
                    # New variable being set
                    set_count=$((set_count + 1))
                    echo "Setting: $var_name"
                fi

                # Export the variable with proper quoting
                export "$var_name"="$var_value"
            fi
        done < .env
        echo "---------------------------------"
        echo "$set_count new variables were set."
        echo "$update_count existing variables were updated."
    else
        echo ".env file not found in the current directory."
    fi
fi
