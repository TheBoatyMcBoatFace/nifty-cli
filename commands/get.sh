#!/bin/bash

# Function to display usage instructions
usage() {
  echo "Usage: $0 RelativeFilePath|URL n[l|c] [begin|end]"
  echo "n: Number of lines ('10l' for 10 lines) or characters ('200c' for 200 characters)"
  echo "[begin|end]: Optional; specify where to begin the extraction (default: begin)"
  exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
fi

# Assign arguments to variables
source="$1"
count_string="$2"
position="${3:-begin}" # Default to 'begin' if not specified

# Validate the second argument format
if [[ ! "$count_string" =~ ^[0-9]+[lc]$ ]]; then
  echo "Error: Second argument must be in the format '10l' or '200c'."
  usage
fi

# Extract the number and the type (l or c) from the second argument
count="${count_string%[lc]}"
type="${count_string: -1}"

# Determine the type of extraction for display
type_description=""
if [ "$type" == "l" ]; then
  type_description="lines"
elif [ "$type" == "c" ]; then
  type_description="characters"
fi

# Validate the position argument
if [ "$position" != "begin" ] && [ "$position" != "end" ]; then
  echo "Error: The third argument must be 'begin' or 'end' if specified."
  usage
fi

# Check if the source is a URL or a file
if [[ "$source" =~ ^https?:// ]]; then
  # Try to fetch the URL content
  content=$(curl -fsS "$source")
  if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch URL '$source'."
    exit 1
  fi
else
  # Check if the file exists
  if [ ! -f "$source" ]; then
    echo "Error: File '$source' not found!"
    exit 1
  fi
  # Read file content
  content=$(cat "$source")
fi

# Print the header
echo
echo "First $count $type_description of $source from the $position"
echo

# Execute the appropriate command
if [ "$position" == "begin" ]; then
  if [ "$type" == "l" ]; then
    # Get the specified number of lines from the beginning
    echo "$content" | head -n "$count"
  elif [ "$type" == "c" ]; then
    # Get the specified number of characters from the beginning
    echo "$content" | head -c "$count"
  fi
elif [ "$position" == "end" ]; then
  if [ "$type" == "l" ]; then
    # Get the specified number of lines from the end
    echo "$content" | tail -n "$count"
  elif [ "$type" == "c" ]; then
    # Get the specified number of characters from the end
    echo "$content" | tail -c "$count"
  fi
fi

# Print a newline at the end
echo
