#!/bin/bash

# In Bash
for d in $(find . -type d -name .git); do
  repo=$(dirname "$d")
  echo "Checking $repo..."
  # Switch to the repo directory
  (cd "$repo" || exit

   # Check if there are changes
   if [ -n "$(git status --porcelain)" ]; then
     echo "  => Dirty"
   else
     echo "  => Clean"
   fi
  )
done

