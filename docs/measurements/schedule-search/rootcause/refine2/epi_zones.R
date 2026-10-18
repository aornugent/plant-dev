# Pinned replays of level k with only the first ("open") or last ("end") added node of each panel
# in C and D removed, panels of four or more intervals at level k - 1; or ("short") the added
# nodes of the panels holding one interval at level 0; "end2" and "open2" take the second-last and
# second added node, which at level 2 lie in level 1's last and first two intervals.
#   Rscript zones.R LIB BASE_DIR BASE_NAME K ZONE OUTNAME
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/epi/mixed.R")  # a copy of epi_mixed.R
zone_nodes <- function(sch, k, zone) {
  unlist(lapply(sch$panels, function(p) { n <- p$n * 2^k
    if (p$lo < REG$C[1] || p$lo >= REG$D[2] || n < 2) return(NULL)
    if ((zone == "short") != (p$n == 1) || (zone != "short" && n / 2 < 4)) return(NULL)
    q <- approx(p$mass / tail(p$mass, 1), p$at, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y
    switch(zone, short = q[seq(1, n - 1, by = 2)], open = q[1], open2 = q[3], end = q[n - 1], end2 = q[n - 3]) })) }
a <- commandArgs(TRUE); sch <- readRDS(file.path(E, "schedules.rds"))$s05; k <- as.numeric(a[4])
base <- file.path(a[2], paste0(a[3], ".rds")); B <- readRDS(base)$node_times
drop <- round(zone_nodes(sch, k, a[5]), 10); stopifnot(all(drop %in% round(B, 10)), !any(drop %in% round(nodes_of(sch, k - 1), 10)))
S <- B[!(round(B, 10) %in% drop)]; out <- file.path(E, "runs", paste0(a[6], ".rds"))
cat(a[6], ": ", length(drop), " nodes removed at ", paste(round(drop, 3), collapse = " "), "\n", sep = "")
tf <- file.path(E, "runs", paste0(a[6], "_times.rds")); saveRDS(S, tf)
env <- c(TOL = "1e-4", ATOL = "1e-4", WEIGHT_SOIL = "10", WEIGHT_MAX = "100", HMAX = "15", SHARE = "0.1", SPLIT = "1",
         REGIME = "episodic", SEED = "31", TRAIT_REL = "a_dG2=-0.2", WEIGHT = file.path(DEV, "window/rule_A/weight_episodic.rds"),
         LIB = a[1], TIMES = tf, OUT = out, PIN = base, FORWARD = "", FIRST = "")
st <- system2("Rscript", file.path(E, "run1.R"), env = paste0(names(env), "=", env),
              stdout = file.path(E, "runs", paste0(a[6], ".log")), stderr = file.path(E, "runs", paste0(a[6], ".log")))
cat(readLines(file.path(E, "runs", paste0(a[6], ".log"))), sep = "\n"); quit(status = st)
