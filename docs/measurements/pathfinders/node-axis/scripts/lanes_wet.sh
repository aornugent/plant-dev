#!/bin/bash
# The long-wet ladders in three lanes, in the pre-registration's priority order.
N=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_nodes
R="bash $N/run1.sh"
( $R wet_D_u108 long-wet t_u108 8; $R wet_D_u215 long-wet t_u215 8; $R wet_D_u429 long-wet t_u429 8 ) &
( $R wet_B_G1 long-wet t_wet_G1 0; $R wet_B_G2 long-wet t_wet_G2 0; $R wet_BD_G1 long-wet t_wet_G1 8; $R wet_L_u215 long-wet t_u215 0 ) &
( $R wet_BD_G2 long-wet t_wet_G2 8; $R wet_L_u54 long-wet t_u54 0; $R wet_D_u54 long-wet t_u54 8; $R wet_B_G3 long-wet t_wet_G3 0 ) &
wait
echo "lanes_wet finished $(date +%T)" >> $N/queue.out
