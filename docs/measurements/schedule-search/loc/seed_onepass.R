# Seed: the pilot's edges, each open gap cut into an even number of equal intervals (at
# most b1/16 before b1, 80 d after); one map pass bisects the panels carrying 75% of the
# summed |move|. Commit the start when 4/3 of the move is under 0.9 eps everywhere.
SHARE <- 0.75; TAU <- 0.9
start <- function(p) { ends <- sort(unique(c(0, p$edges, 39.6))); G <- c(); drop <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; open <- p$shut((a + b) / 2) < 0.5
    r <- (b - a) / if (b <= p$b1 + 1e-9) p$b1 / 16 else 80 / 365; n <- if (!open || r <= 1) 1 else 2 * ceiling(r / 2)
    G <- c(G, seq(a, b, length.out = n + 1)[-(n + 1)]); if (n > 1) drop <- c(drop, seq(a, b, length.out = n + 1)[seq(2, n, by = 2)]) }
  G <- sort(unique(round(G, 10))); list(S = G, drop = which(G %in% round(drop, 10))) }
algorithm <- function(ctx) {
  g <- start(ctx$pilot); a <- ctx$run(g$S, drop = g$drop); m <- a$map
  o <- order(-abs(m$move)); pick <- o[seq_len(which(cumsum(abs(m$move[o])) >= SHARE * sum(abs(m$move)))[1])]
  j <- g$drop[pick]; S1 <- sort(unique(c(g$S, (g$S[j - 1] + g$S[j]) / 2, (g$S[j] + g$S[j + 1]) / 2)))
  b <- ctx$run(S1); k <- names(a$q); e <- ctx$eps(k); d <- a$q[k] - b$q[k]
  if (all(abs(4 / 3 * d / e) < TAU)) return(list(use = list(g$S), answer = a$q[k], estimate = 4 / 3 * d))
  list(use = list(S1), answer = b$q[k], estimate = d / 3)
}
