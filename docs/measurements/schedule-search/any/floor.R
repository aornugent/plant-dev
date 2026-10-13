source("lab.R"); source("p_a04.R")
for (cs in names(CASES)) { cd <- CD[[cs]]; p <- cd$pilot; P <- pair(mkctx(cs))
  Sf <- build_graded(p, function(b) 10)   # widest the range allows
  Se <- sort(unique(c(0, p$edges)))
  e <- function(S) { x <- feat(cs, S); E <- bandE(cs, S); c(worst = max(abs(c(x[1], rowSums(E)))), x[-1]) }
  cat(sprintf("%-12s A n %d cost %.0f worst %.2f | floor n %d cost %.0f worst %.2f bands %s | edges-only n %d cost %.0f\n", cs, length(P$A), cost(cs, P$A), e(P$A)[1],
    length(Sf), cost(cs, Sf), e(Sf)[1], paste(sprintf("%.2f", e(Sf)[-1]), collapse = " "), length(Se), cost(cs, Se))) }
