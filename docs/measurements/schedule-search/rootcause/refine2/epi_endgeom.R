# Width of each spell's last interval against t_r, at scale 1 (level 0), for the five cases.
LIFETIME <- 40; source("/home/user/plant-dev/harness/schedule/refine.R")
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
for (cs in c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")) {
  s <- readRDS(file.path(SP, "refine/s1", paste0(cs, ".rds")))$schedule
  last <- do.call(rbind, lapply(s$panels, function(p) { if (p$n < 2) return(NULL); S <- nodes_of(list(panels = list(p)), 0)
    S <- c(S, p$hi); data.frame(lo = p$lo, hi = p$hi, n = p$n, last_d = (p$hi - S[length(S) - 1]) * 365, mid_d = median(diff(S)) * 365) }))
  last <- last[last$hi <= s$spells$t90, ]
  r <- last$last_d / s$t_r
  cat(sprintf("%-13s t_r %.1f d | spells >=2 intervals before t90: %d | last interval / t_r: median %.2f, max %.2f, share > 1: %.2f | median interval %.0f d\n",
    cs, s$t_r, nrow(last), median(r), max(r), mean(r > 1), median(last$mid_d)))
  if (cs == "epi-adG208") print(format(transform(last, r = round(r, 2)), digits = 4), row.names = FALSE) }
