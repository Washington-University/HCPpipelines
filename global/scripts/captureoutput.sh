#!/bin/bash
set -eu

#emulate fsl_sub output capturing while running locally
#use exec so the command gets the same pid as the log files use
#note, exec doesn't understand env variables like "OMP_NUM_THREADS=1 wb_command ..."
#so, you need to run "OMP_NUM_THREADS=1 captureoutput.sh wb_command ..." instead

#remove path from executable, for log naming
logname=$(basename "$1")

#tell the user what is going on
echo "logging output to $logname.o$$ and $logname.e$$"

exec "$@" > "$logname.o$$" 2> "$logname.e$$"
