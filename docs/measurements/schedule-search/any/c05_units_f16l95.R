# c03: as c02, but open gaps left as one interval (unmapped) are units too: their error is
# read from the nearest panel's density (d = |m| / 6h^3) times h^3, and bisecting one adds a
# node. Every region bisects the units holding share s of its error.
ge <- function(n, d) as.numeric(Sys.getenv(n, d))
NF <- ge("NF", "16"); DL <- ge("DL", "95"); DL2 <- ge("DL2", "280"); SHARE <- ge("SHARE", "0.95"); WIN <- ge("WIN", "100"); TAU <- ge("TAU", "0.9")
start <- function(p) { ends <- sort(unique(c(0, p$edges, 39.6))); G <- c(); drop <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; open <- p$shut((a + b) / 2) < 0.5
    st <- if (b <= p$b1 + 1e-9) p$b1 / NF else if (a < 20) DL / 365 else DL2 / 365
    r <- (b - a) / st; n <- if (!open || r <= 1) 1 else 2 * ceiling(r / 2)
    G <- c(G, seq(a, b, length.out = n + 1)[-(n + 1)]); if (n > 1) drop <- c(drop, seq(a, b, length.out = n + 1)[seq(2, n, by = 2)]) }
  G <- sort(unique(round(G, 10))); list(S = G, drop = which(G %in% round(drop, 10))) }
# Units: each mapped panel (error |m|/3) and each unmapped open interval (error d h^3, d from
# the nearest panel). Bisecting a unit removes 3/4 of its error.
units <- function(p, S, drop, m) {
  hp <- (S[drop + 1] - S[drop - 1]) / 2; dp <- m / (6 * hp^3); mid <- S[drop]
  u <- data.frame(lo = S[drop - 1], hi = S[drop + 1], b = mid, err = m / 3, panel = TRUE)
  lo <- S[-length(S)]; hi <- S[-1]; inp <- rep(FALSE, length(lo)); inp[c(drop - 1, drop)] <- TRUE
  sg <- which(!inp & p$shut((lo + hi) / 2) < 0.5)
  if (length(sg)) { c <- (lo[sg] + hi[sg]) / 2; dn <- dp[vapply(c, function(x) which.min(abs(mid - x)), 1L)]
    u <- rbind(u, data.frame(lo = lo[sg], hi = hi[sg], b = c, err = dn * (hi[sg] - lo[sg])^3, panel = FALSE)) }
  u }
refine <- function(S, u) { new <- ifelse(u$panel, NA, (u$lo + u$hi) / 2)
  pn <- u[u$panel, ]; sort(unique(round(c(S, (u$lo + u$hi)[!u$panel] / 2, (pn$lo + pn$b) / 2, (pn$b + pn$hi) / 2), 10))) }
windows <- function(b, b1) ifelse(b < b1, 0, 1 + floor((b - b1) / WIN))
pick_share <- function(u, b1, s) { w <- windows(u$b, b1); pick <- c()
  for (k in unique(w)) { i <- which(w == k); o <- i[order(-u$err[i])]; if (sum(u$err[o]) <= 0) next
    pick <- c(pick, o[seq_len(which(cumsum(u$err[o]) >= s * sum(u$err[o]) - 1e-12)[1])]) }
  pick }
algorithm <- function(ctx) {
  p <- ctx$pilot; g <- start(p); a <- ctx$run(g$S, drop = g$drop); u <- units(p, g$S, g$drop, abs(a$map$move))
  pick <- pick_share(u, p$b1, SHARE); S1 <- refine(g$S, u[pick, ])
  b <- ctx$run(S1); k <- names(a$q); d <- a$q[k] - b$q[k]; e <- ctx$eps(k)
  E <- sum(u$err); M <- 0.75 * sum(u$err[pick])
  if (all(abs(E / M * d / e) <= TAU)) return(list(use = list(g$S), answer = a$q[k], estimate = E / M * d))
  list(use = list(S1), answer = b$q[k], estimate = (E - M) / M * d)
}
