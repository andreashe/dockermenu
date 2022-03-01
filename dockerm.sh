#!/usr/bin/env bash

# change to script directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

# run the script
/usr/bin/env perl main.pl