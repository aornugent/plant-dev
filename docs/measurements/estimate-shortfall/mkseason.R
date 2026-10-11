# P3s: pass 3 with every open interval born in [3.7, 20] split to at most 1/16 yr;
# Bs its bisection; Cs drops every other node among those that are not first-pass edges.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
t <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds"))
cr <- readRDS(file.path(S, "placed2/runs/m_th0_f_episodic.rds"))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
rate <- approxfun(cr$start, cr$rate, method = "constant", rule = 2)
add <- unlist(lapply(seq_len(length(t) - 1), function(i) { a <- t[i]; b <- t[i + 1]
  if (a < 3.7 || a >= 20 || rate((a + b) / 2) < 0.01 || b - a <= 1 / 16) return(NULL)
  n <- ceiling((b - a) * 16); seq(a, b, length.out = n + 1)[-c(1, n + 1)] }))
p <- sort(unique(c(t, add))); keep <- round(p, 9) %in% round(ed, 9) | seq_along(p) %in% c(1, length(p))
free <- which(!keep); drop <- free[seq(2, length(free), by = 2)]
saveRDS(p, file.path(S, "rc/P3s.rds")); saveRDS(sort(c(p, head(p, -1) + diff(p) / 2)), file.path(S, "rc/Bs.rds")); saveRDS(p[-drop], file.path(S, "rc/Cs.rds"))
cat(sprintf("added %d: P3s %d nodes, Cs %d, Bs %d\n", length(add), length(p), length(p) - length(drop), 2 * length(p) - 1))
