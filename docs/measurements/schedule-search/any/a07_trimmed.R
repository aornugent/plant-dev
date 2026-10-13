# a05_fill built on the edges a run needs, rather than trimmed after: no edge after
# b = 25, and no edge around a shut gap under 10 d (a spell whose gaps merge on both
# sides keeps its start edge). A merged gap and everything after 25 count as open, so
# the graded build spaces them by the target like any spell, and the check's ratio and
# bisection see the intervals the run will have.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", environment())
GAP <- ev("GAP", 10) / 365; LATE <- ev("LATE", 25)
trim_pilot <- function(p) { e <- sort(p$edges); m <- (head(e, -1) + e[-1]) / 2
  gap <- p$shut(m) > 0.5 & diff(e) < GAP; k <- which(gap); both <- k[(k + 2) %in% k]
  drop <- setdiff(unique(c(e[-length(e)][gap], e[-1][gap])), e[both + 1])
  lo <- e[-length(e)][gap]; hi <- e[-1][gap]; shut0 <- p$shut
  p$edges <- e[!(e %in% drop) & e <= LATE]
  p$shut <- function(b) { s <- shut0(b); s[b > LATE] <- 0; for (j in seq_along(lo)) s[b > lo[j] & b < hi[j]] <- 0; s }
  p }
a05_algorithm <- algorithm
algorithm <- function(ctx) { ctx$pilot <- trim_pilot(ctx$pilot); a05_algorithm(ctx) }
