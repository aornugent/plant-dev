# Coarsening against bisection with breakpoints protected: pass 3 (edges protected) and
# P3o (edges and dry-soil onsets protected); errors against the reference, in eps.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
Q <- file.path(D, "schedtest/placed2/runs"); NR <- file.path(D, "node_rule/ladder/runs"); PL <- file.path(D, "schedtest/placement/runs")
lj <- function(f) log(readRDS(f)$stand$J); ref <- { a <- lj(file.path(NR, "u429_episodic.rds")); b <- lj(file.path(PL, "u857_episodic.rds")); b + (b - a) / 3 }
f <- function(n) file.path(Q, paste0(n, ".rds"))
line <- function(lab, P, C, B) { p <- lj(f(P)); c <- lj(f(C)); b <- lj(f(B))
  cat(sprintf("%-26s err %+.3f | (C-P)/3 %+.3f | 4/3 (P-B) %+.3f | (C-P)/(P-B) %.2f | nodes %d\n", lab, (p - ref) / .025, (c - p) / 3 / .025,
    4 / 3 * (p - b) / .025, (c - p) / (p - b), length(readRDS(f(P))$stand$nodes$birth))) }
line("P3, odd coarsening", "fwd_u108e_p3_episodic", "rc_C_u108e_episodic_p3", "rc_B_u108e_episodic_p3")
line("P3, edges protected", "fwd_u108e_p3_episodic", "rc_C3p_episodic", "rc_B_u108e_episodic_p3")
line("P3o, edges+onsets protected", "rc_P3o_episodic", "rc_Co_episodic", "rc_Bo_episodic")
if (file.exists(f("rc_Bs_episodic"))) line("P3s, late windows <= 23 d", "rc_P3s_episodic", "rc_Cs_episodic", "rc_Bs_episodic")
