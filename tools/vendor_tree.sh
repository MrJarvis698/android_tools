#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2019 Shivam Kumar Jha <jha.shivam3@gmail.com>
#
# Helper functions

# Store project path
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"

# Text format
source $PROJECT_DIR/helpers/common_script.sh

# Exit if no arguements
if [ -z "$1" ] ; then
    echo -e "Supply ROM source as arguement!"
    exit 1
fi

# o/p
for var in "$@"; do
    # Check if directory
    if [ ! -d "$var" ] ; then
        echo -e "Supply ROM path as arguement!"
        break
    fi

    # Create vendor tree repo
    source $PROJECT_DIR/helpers/rom_vars.sh "$var" > /dev/null 2>&1
    VT_REPO=$(echo vendor_$BRAND\_$DEVICE)
    VT_REPO_DESC=$(echo "Vendor tree for $MODEL")
    curl https://api.github.com/user/repos\?access_token=$GIT_TOKEN -d '{"name": "'"$VT_REPO"'","description": "'"$VT_REPO_DESC"'","private": true,"has_issues": true,"has_projects": false,"has_wiki": true}' > /dev/null 2>&1

    # Extract vendor blobs
    bash "$PROJECT_DIR/helpers/extract_blobs/extract-files.sh" "$var"

done
