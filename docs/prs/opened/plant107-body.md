On the birth-date coordinate, the light at a height sums every cohort that reaches it. A crown adds exactly zero below its own height, so the build sums the cohorts tallest first and reads each knot's light from a running total. That order is the node list's order until two cohorts cross in height, which TF24's reserve-limited growth lets two cohorts born days apart do. From then on the build evaluated every crown at every knot of the light environment, for the rest of the run.

The build now sorts the nodes by height when they are out of order, with the order the height coordinate already uses for a crossed list (`ascending_by_abscissa()`), and keeps the running total. Only the order of summation changes, and only where crowns cross. A run in which no crowns cross gives bit-identical results, and no reference moves.

Closes #107

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
