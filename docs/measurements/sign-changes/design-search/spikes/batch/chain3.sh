#!/bin/bash
# After the three running gradient runs (PIDs given), the second-difference
# forwards (m2, m1, then m4), then the remaining gradient runs.
for p in "$@"; do while kill -0 "$p" 2>/dev/null; do sleep 20; done; done
cd "$(dirname "$0")"
ARMS=arms2.txt ./run_grad.sh
ARMS=arms3.txt ./run_grad.sh
ARMS=arms1.txt ./run_grad.sh
echo "CHAIN3 DONE $(date +%T)"
