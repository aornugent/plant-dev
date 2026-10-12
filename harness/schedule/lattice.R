# The schedule lattice of plan-schedule-search.md: per case, birth dates from the
# founders' level f (even nodes over [0, b1)) and the late spacing l (days), with the
# pilot's edges as nodes and base nodes born while establishment is shut dropped.
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
RUNS <- file.path(DEV, "schedtest/placed2/runs")

# Training cases: record, trait move, run setting and pilot. `pf` is long drought's
# setting (no soil share, no splits); `nr` the others'.
CASES <- list(
  episodic = list(rec = "episodic", trait = "", set = "nr", pilot = "m_th0_f_episodic"),
  dry = list(rec = "dry", trait = "", set = "nr", pilot = "m_th0_f_dry"),
  `long-wet` = list(rec = "long-wet", trait = "", set = "nr", pilot = "m_th0_f_long-wet"),
  `long-drought` = list(rec = "long-drought", trait = "", set = "pf", pilot = "m_th0_f_long-drought"),
  `episodic-lma` = list(rec = "episodic", trait = "lma=0.25", set = "nr", pilot = "m_lma125_f_episodic"))
F_LEVELS <- c(8, 16, 32, 64)
L_LEVELS <- c(140, 70, 35, 17.5)

# Edges and the shut record from a pilot's creation record.
pilot_edges <- function(case) {
  cr <- readRDS(file.path(RUNS, paste0(CASES[[case]]$pilot, ".rds")))$stand$creation
  op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  ed <- cr$end[e][-length(e)]; closing <- op[e][-length(e)]
  keep <- ed > 0 & ed < 39.6
  list(edges = ed[keep], b1 = ed[keep][closing[keep]][1],
       shut = approxfun(c(cr$start, tail(cr$end, 1)), c(as.numeric(!op), as.numeric(!tail(op, 1))),
                        method = "constant", rule = 2))
}

lattice_schedule <- function(case, f, l, edges = TRUE) {
  p <- pilot_edges(case); b1 <- p$b1; h <- l / 365
  base <- c(seq(0, b1, length.out = f + 1)[-(f + 1)], seq(b1, 39.6, by = h))
  hloc <- ifelse(base < b1, b1 / f, h)
  keep <- p$shut(base) < 0.5
  if (edges) keep <- keep & vapply(seq_along(base), function(i) all(abs(p$edges - base[i]) > hloc[i] / 2), TRUE)
  s <- sort(unique(c(base[keep], if (edges) p$edges)))
  s[c(TRUE, diff(s) > 1e-6)]
}
