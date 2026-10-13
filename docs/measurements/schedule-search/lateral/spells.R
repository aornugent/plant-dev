# Open spells between pilot edges: widths, and rows the leader spends on edge nodes that one
# midpoint node per short spell would replace (two edges -> one node; shared edges counted once).
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
env <- new.env(); sys.source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/structure/c05_graded.R", env)
for (cs in names(CASES)) { cd <- prepare(cs); p <- cd$pilot; Sc <- build_graded(p, env$hfun_of(p)); co <- coef(cd$rowsfit)
  rr <- function(S) co[1] * length(S) + co[2] * sum(H - S)
  ends <- sort(unique(c(0, p$edges, H))); lo <- head(ends, -1); hi <- ends[-1]; open <- p$shut((lo + hi) / 2) < 0.5
  w <- (hi - lo)[open] * 365; L <- lo[open]; U <- hi[open]
  for (X in c(30, 85)) { s <- w < X & L > p$b1
    # replace each short spell's nodes (its edges and any interior) by its midpoint
    drop <- Sc[vapply(Sc, function(b) any(s & b >= L - 1e-9 & b <= U + 1e-9), TRUE)]
    S2 <- sort(unique(c(setdiff(Sc, drop), ((L + U) / 2)[s])))
    cat(sprintf("%-13s spells %d (after b1 %d), median width %.0f d; spells < %d d after b1: %d, nodes %d -> %d, Cc rows saved %.1f%%\n",
      cs, length(w), sum(L > p$b1), median(w), X, sum(s), length(Sc), length(S2), 100 * (1 - rr(S2) / rr(Sc)))) } }
