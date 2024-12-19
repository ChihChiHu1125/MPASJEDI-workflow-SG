#!/bin/bash

# Define the directory where your YAML files are located
YAML_DIR="."

# Loop through all YAML files in the directory
for file in "$YAML_DIR"/*.yaml; do
  # Check if the file exists and is a regular file
  if [ -f "$file" ]; then
    echo "Processing file: $file"
    
    # Use sed to replace ': *reduceObsSpace' with '- *reduceObsSpace' in each file
    sed -i 's/: \*reduceObsSpace/- \*reduceObsSpace/g' "$file"
    
    echo "Updated file: $file"
  fi
done

echo "Replacement done for all YAML files."

