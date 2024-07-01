#!/bin/bash

################################################################################
#
# FILE:         remove-bitmaps.sh
#
# DESCRIPTION:  This script removes specified PNG files and their associated
#               symbolic links.
#
# AUTHOR:       Zoltan Kiraly <public@zoltankiraly.com>
#
# USAGE:        ./remove-bitmaps.sh [--dry-run] file1.png [file2.png ...]
#
# OPTIONS
#   --dry-run   : Perform a dry run, simulating removal without actual deletion.
#
# NOTES:        - The script expects 'Moka' directory to be located one folder
#                 above where this script resides.
#
################################################################################

# Function to display usage instructions
display_usage() {
  echo "Usage: $0 [--dry-run] file1.png [file2.png ...]"
  echo ""
  echo "Options:"
  echo "  --dry-run   Perform a dry run, do not remove files or symlinks."
  exit 1
}

# Check if any arguments are provided
if [ $# -eq 0 ]; then
  display_usage
fi

# Resolve the path to the "Moka" directory
moka_dir=$(realpath "$(dirname "$(readlink -f "$0")")/../Moka")

if [ ! -d "$moka_dir" ]; then
  echo "Error: The 'Moka' directory does not exist or is not accessible."
  exit 1
fi

# Initialize dry_run variable
dry_run=false
files=()

# Parse command line arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=true
      echo "Running in dry-run mode. No changes will be made."
      ;;
    *)
      files+=("$arg")
      ;;
  esac
done

# Function to remove a specified file
remove_bitmap() {
  local file="$1"

  for subdir in "$moka_dir"/*/*; do
    # Check if the file exists and remove it
    if [ -f "$subdir/$file" ]; then
      if [ "$dry_run" != true ]; then
        rm "$subdir/$file"
        echo "Removed file: $subdir/$file"
      else
        echo "Dry run: removing file: $subdir/$file"
      fi
    fi
  done
}

# Function to remove symlinks associated with a specified file
remove_symlinks() {
  local file="$1"

  for subdir in "$moka_dir"/*/*; do
    # Check if the symlink exists and points to the specified file, then remove it
    for symlink_path in "$subdir"/*; do
      if [ -L "$symlink_path" ]; then
        target=$(readlink "$symlink_path")
        if [ "$(basename "$target")" = "$file" ]; then
          if [ "$dry_run" != true ]; then
            rm "$symlink_path"
            echo "Removed symlink: $symlink_path -> $target"
          else
            echo "Dry run: removing symlink: $symlink_path -> $target"
          fi
        fi
      fi
    done
  done
}

# Loop through each file provided
for file in "$@"; do
  remove_bitmap "$file"
  remove_symlinks "$file"
done