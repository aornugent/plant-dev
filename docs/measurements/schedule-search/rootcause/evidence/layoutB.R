# layoutB.R: the revised design's layout B from a pilot. Breakpoints: 0 and every edge,
# opening and shutting, up to t90; one late panel from the last breakpoint to the horizon.
# rho0 = a09's graded density with its ages from T(t): the 100 d cap and the fate reference
# window end at t50 (for 20), edges after t90 are not breakpoints (for 25). A panel whose
# integral of rho0 is at most 1 keeps one interval (a short spell, not replayed); every
# other panel gets an even count at equal rho0-mass. Also the replay's drops (odd and even
# interior nodes), the short spells' bisection, and the bound's proxy.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
TW <- readRDS(file.path(SC, "evidence", "q6_time.rds"))
ages_of <- function(cs) { r <- TW[TW$case == cs, ]; c(t50 = r$t50, t90 = r$t10) }   # t10 column: T <= 0.1, i.e. 90% produced
hfun_T <- function(p, t50) { l1 <- alg$layer_end(p); n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  ref <- median(log(pmax(n$nrr[n$birth > p$b1 & n$birth < t50], 1e-300)))
  cap <- function(b) if (b < p$b1) p$b1 / 12 else if (b < t50) 100 / 365 else 280 / 365
  list(h = function(b) min(cap(b), if (b < p$b1) { if (b < l1) p$b1 / alg$LAYER else p$b1 / 12 } else alg$BG / 365 * max(1, exp(alg$K * (ref - lf(b))))), cap = cap) }
layout_B <- function(cs, s = 1, p = pilot_of(cs), px = pilot_run(cs), gfun = NULL, double = FALSE, add = 0) { a <- ages_of(cs); hf <- hfun_T(p, a[["t50"]]); ea <- edges_all(cs, px)
  br <- sort(unique(c(0, ea$b[ea$b <= a[["t90"]]], H))); g <- seq(0, H, length.out = 40001); dg <- diff(g)[1]; gm <- g[-1] - dg / 2
  open <- p$shut(gm) < 0.5; rho <- ifelse(open, 1 / pmin(vapply(gm, hf$h, 0), vapply(gm, hf$cap, 0)), 0)
  # graded toward each shutting breakpoint: rho0 x g(days before the next shutting)
  if (!is.null(gfun)) { cl <- ea$b[!ea$opening & ea$b <= a[["t90"]]]; nx <- cl[pmin(findInterval(gm, cl) + 1, length(cl) + 1)]
    d <- ifelse(is.na(nx), Inf, (nx - gm) * 365); rho <- rho * ifelse(is.finite(d), gfun(d), 1) }
  # the a09 proxy weight per unit birth date: pilot offspring ^ 0.6 where open
  lf <- approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2); pw <- ifelse(open, exp(alg$PW * lf(gm)), 0)
  S <- c(); pan <- list(); member <- list()
  for (i in seq_len(length(br) - 1)) { lo <- br[i]; hi <- br[i + 1]; k <- gm >= lo & gm < hi; S <- c(S, lo); x <- c()
    m <- s * sum(rho[k]) * dg; n <- if (!any(open[k])) 0 else if (m <= 1 + 1e-9) 1 else 2 * ceiling(m / 2 - 1e-9)
    if (double && n >= 1) n <- 2 * n
    if (add > 0 && n >= 2) n <- n + add
    if (n >= 2) { cw <- c(0, cumsum(rho[k] * dg)); u <- c(lo, gm[k] + dg / 2); x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y }
    member[i] <- list(x); S <- c(S, x)
    pan[[i]] <- data.frame(lo = lo, hi = hi, m = m, n_int = n, open_days = sum(open[k]) * dg * 365) }
  S <- sort(unique(round(S, 10))); P <- do.call(rbind, pan)
  odd <- round(unlist(lapply(member, function(x) if (length(x)) x[seq(1, length(x), by = 2)])), 10)
  even <- round(unlist(lapply(member, function(x) if (length(x) >= 3) x[seq(2, length(x) - 1, by = 2)])), 10)
  short <- which(P$n_int == 1); bis <- sort(unique(round(c(S, (P$lo[short] + P$hi[short]) / 2), 10)))
  # proxy per interval: integral of pw x width^2 over the interval (error ~ count x width^2)
  prox <- function(S2) { lo <- head(S2, -1); hi <- c(S2[-1]); vapply(seq_along(lo), function(j) sum(pw[gm >= lo[j] & gm < hi[j]]) * dg * (hi[j] - lo[j])^2, 0) }
  pr <- prox(c(S, H)); ip <- findInterval(head(c(S, H), -1), br)
  list(S = S, panels = P, odd = odd, even = even, bis = bis, short = short, breaks = br, ages = a,
       proxy_short = sum(pr[P$n_int[ip] == 1]), proxy_rep = sum(pr[P$n_int[ip] >= 2])) }
