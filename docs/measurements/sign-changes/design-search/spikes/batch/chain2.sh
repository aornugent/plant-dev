#!/bin/bash
# After the gradient runs (PID in $1), the forwards for second differences.
while kill -0 "$1" 2>/dev/null; do sleep 30; done
cd "$(dirname "$0")" && ARMS=arms2.txt ./run_grad.sh
