#!/bin/bash

################################################################################
#
# FILE:        update-symlinks.sh
#
# DESCRIPTION: This script manages synchronization between symbolic links
#              listed in 'symlinks.list' and their counterparts in various
#              directories within the 'Moka' folder. It ensures that any
#              changes made to 'symlinks.list' are accurately reflected
#              within these directories.
#
# AUTHOR:      Zoltan Kiraly <public@zoltankiraly.com>
#
# USAGE:       ./update-symlinks.sh [--dry-run]
#
# OPTIONS:
#   --dry-run  : Perform a dry run without actually modifying any symlinks.
#
# NOTES:       - The script expects 'Moka' directory to be located one folder
#                above where this script resides.
#
################################################################################

# Check if --dry-run option is provided
dry_run=false
if [ "$1" = "--dry-run" ]; then
  dry_run=true
  echo "Running in dry-run mode. No changes will be made."
fi

# Resolve the path to the "Moka" directory
moka_dir=$(realpath "$(dirname "$(readlink -f "$0")")/../Moka")

if [ ! -d "$moka_dir" ]; then
  echo "Error: The 'Moka' directory does not exist or is not accessible."
  exit 1
fi

# Resolve the path to the file containing symlinks
symlinks_file=$(dirname "$0")/symlinks.list

if [ ! -f "$symlinks_file" ]; then
  echo "Error: The file $symlinks_file does not exist or is not accessible."
  exit 1
fi

# Validate the symlinks file
if grep -qEv '^\S+\s+\S+$' "$symlinks_file"; then
  echo "Error: Invalid format in $symlinks_file. Each line should contain exactly two columns."
  exit 1
fi

# Function to create symlink in a specific folder
create_symlink() {
  local folder="$1"
  local source="$2"
  local destination="$3"

  # Check if the source file exists and destination is not a symbolic link
  if [ -f "$folder/$source" ] && [ ! -L "$folder/$destination" ]; then
    if [ "$dry_run" != true ]; then
      ln -s "$source" "$folder/$destination"
      echo "Created symlink $destination -> $source in $folder"
    else
      echo "Dry run: creating symlink $destination -> $source in $folder"
    fi
  fi
}

# Function to remove symlink from a specific folder
remove_symlink() {
  local folder="$1"
  local destination="$2"

  # Remove the symlink if it exists
  if [ -L "$folder/$destination" ]; then
    if [ "$dry_run" != true ]; then
      rm "$folder/$destination"
      echo "Removed symlink $destination from $folder"
    else
      echo "Dry run: removing symlink $destination from $folder"
    fi
  fi
}

# Find differences between sorted unique symlinks in $symlinks_file and actual symlinks in $moka_dir
# For more information, see 'man comm'
comm_output=$(comm -3 <(sort -u "$symlinks_file") <(find "$moka_dir" -type l -printf '%l %f\n' | sort -u) | sort)

# NOTE: We cannot assure that the 'comm' command always displays items marked for deletion first,
# so we use two while loops to ensure the order.

# Process deletions first
while IFS= read -r line; do
  # Check if the line is indented (indicating a remove action)
  if [[ "$line" =~ ^[[:space:]]+ ]]; then
    # Remove action (destination is the second part of the line)
    destination=${line##* }
    # Iterate through each subdirectory in $moka_dir and remove symlink
    for subdir in "$moka_dir"/*/*; do
      remove_symlink "$subdir" "$destination"
    done
  fi
done <<< "$comm_output"

# Process additions after deletions
while IFS= read -r line; do
  # Check if the line is not indented (indicating an add action)
  if [[ ! "$line" =~ ^[[:space:]]+ ]]; then
    # Add action (source is the first part, destination is the second part)
    source=${line%% *}
    destination=${line##* }
    # Iterate through each subdirectory in $moka_dir and create symlink
    for subdir in "$moka_dir"/*/*; do
      create_symlink "$subdir" "$source" "$destination"
    done
  fi
done <<< "$comm_output"