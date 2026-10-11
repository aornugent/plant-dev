# P3o: pass 3 plus the dry-soil rain onsets (layer-1 water < 0.2 before a rise > 0.05)
# not within a day of a node; Bo its bisection; Co drops every other node among those
# that are neither first-pass edges nor onsets.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
t <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds")); d <- readRDS(file.path(S, "rc/onsets_episodic.rds"))
cr <- readRDS(file.path(S, "placed2/runs/m_th0_f_episodic.rds"))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
on <- d$t[d$open & d$before < 0.2]; on <- on[vapply(on, function(z) min(abs(t - z)), 0) > 1 / 365]
p <- sort(c(t, on)); keep <- round(p, 9) %in% round(c(ed, on), 9) | seq_along(p) %in% c(1, length(p))
free <- which(!keep); drop <- free[seq(2, length(free), by = 2)]
saveRDS(p, file.path(S, "rc/P3o.rds")); saveRDS(sort(c(p, head(p, -1) + diff(p) / 2)), file.path(S, "rc/Bo.rds")); saveRDS(p[-drop], file.path(S, "rc/Co.rds"))
saveRDS(p[-drop], file.path(S, "rc/Co_coarse.rds"))
cat(sprintf("onsets added %d: P3o %d nodes, Bo %d, Co %d (protected %d)\n", length(on), length(p), 2 * length(p) - 1, length(p) - length(drop), sum(keep)))
