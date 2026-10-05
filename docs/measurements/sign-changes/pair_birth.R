# What a choice of the split moves (prereg.txt, tenth extension).
#   OUTD=... PLANT_LIB=... Rscript pair_birth.R choose   the pair and the passage to bisect
#   Rscript pair_birth.R jump W LO HI OUT_LO OUT_HI   the jump across W's bracket
OUTD <- Sys.getenv("OUTD")
args <- commandArgs(TRUE)
# Each node's share of J: its establishment weight times its net reproduction
# ratio times the density of patches of its age at its birth (node_parts.R).
if (nzchar(Sys.getenv("PLANT_LIB"))) .libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
share_of <- function(x) {
  n <- x$stand$nodes
  m <- min(length(n$establishment), length(n$nrr))
  pd <- plant::Weibull_Disturbance_Regime(x$setting$lifetime)
  w <- n$establishment[1:m] * n$nrr[1:m] * vapply(n$birth[1:m], pd$density, 0)
  w / sum(w)
}
splits <- function(r) {
  x <- grep("^split ", readLines(file.path(OUTD, sprintf("scan_%s.txt", r))), value = TRUE)
  read.table(text = x, col.names = c("tag", "t", "h", "p", "n", "u1", "u2", "v0", "v1", "inside"))
}
if (args[1] == "choose") {
  r_other <- Sys.getenv("R_OTHER", "-1e-3")
  a <- splits("0"); b <- splits(r_other)
  share <- share_of(readRDS(file.path(OUTD, "scan_0.rds")))
  key <- function(s) paste(s$p, sprintf("%.12f", s$t))
  only <- function(x, y) x[!key(x) %in% key(y), ]
  pairs <- rbind(transform(only(a, b), side = "0"), transform(only(b, a), side = r_other))
  pairs <- pairs[pairs$n == 2, ]
  # A passage: one cut at one r, none there at the other, which has the node's cut
  # in the adjacent step.
  adjacent <- function(x, y) {
    x <- only(x[x$n == 1, ], y)
    keep <- vapply(seq_len(nrow(x)), function(i) {
      z <- y[y$p == x$p[i] & y$n == 1, ]
      any(abs(z$t - (x$t[i] + x$h[i])) < 1e-12 | abs(x$t[i] - (z$t + z$h)) < 1e-12)
    }, logical(1))
    x[keep, ]
  }
  passages <- rbind(transform(adjacent(a, b), side = "0"),
                    transform(adjacent(b, a), side = r_other))
  cat(sprintf("node steps split at r = 0 and not at r = %s: %d; at %s and not at 0: %d\n",
              r_other, nrow(only(a, b)), r_other, nrow(only(b, a))))
  cat(sprintf("pairs first cut between them: %d; passages: %d\n", nrow(pairs), nrow(passages)))
  pick <- function(x) {
    if (!nrow(x)) return(NULL)
    x$share <- share[x$p + 1]
    x[order(-x$share, x$t), ][1, ]
  }
  for (kind in c("pair", "passage")) {
    s <- pick(if (kind == "pair") pairs else passages)
    if (is.null(s)) { cat(sprintf("%s none\n", kind)); next }
    ta <- sprintf("%.4f", s$t)
    tb <- ta
    if (kind == "passage") {
      other <- if (s$side == "0") b else a
      z <- other[other$p == s$p & other$n == 1 &
                 (abs(other$t - (s$t + s$h)) < 1e-12 | abs(s$t - (other$t + other$h)) < 1e-12), ]
      tb <- sprintf("%.4f", z$t[1])
    }
    cat(sprintf("%s P=%d TA=%s TB=%s side=%s share=%.4g day=%.3f u1=%.4g u2=%.4g\n", kind, s$p,
                ta, tb, s$side, s$share, s$t * 365, s$u1, s$u2))
  }
} else if (args[1] == "jump") {
  W <- args[2]
  lo <- args[3]; hi <- args[4]; out_lo <- args[5]; out_hi <- args[6]
  lnJ <- function(r) log(readRDS(file.path(W, sprintf("r_%s.rds", r)))$stand$J)
  rl <- as.numeric(lo); rh <- as.numeric(hi)
  s_lo <- (lnJ(lo) - lnJ(out_lo)) / (rl - as.numeric(out_lo))
  s_hi <- (lnJ(out_hi) - lnJ(hi)) / (as.numeric(out_hi) - rh)
  change <- lnJ(hi) - lnJ(lo)
  jump <- change - 0.5 * (s_lo + s_hi) * (rh - rl)
  cat(sprintf("bracket [%s, %s], width %.3g: ln J changes %+.4e; slopes %.6f and %.6f; jump %+.4e\n",
              lo, hi, rh - rl, change, s_lo, s_hi, jump))
  key <- function(f) {
    x <- grep("^split ", readLines(f), value = TRUE)
    s <- read.table(text = x, col.names = c("tag", "t", "h", "p", "n", "u1", "u2", "v0", "v1", "inside"))
    setNames(paste(s$n, signif(s$u1, 6), signif(s$u2, 6)), paste(s$p, sprintf("%.12f", s$t)))
  }
  a <- key(file.path(W, sprintf("log_%s.txt", lo))); b <- key(file.path(W, sprintf("log_%s.txt", hi)))
  d <- union(setdiff(names(a), names(b)), setdiff(names(b), names(a)))
  both <- intersect(names(a), names(b))
  moved <- both[a[both] != b[both] & sub(" .*", "", a[both]) != sub(" .*", "", b[both])]
  cat(sprintf("node steps split at one end only: %s\n", paste(d, collapse = "; ")))
  cat(sprintf("node steps cut a different number of times: %s\n",
              if (length(moved)) paste(moved, collapse = "; ") else "none"))
  for (k in d) cat(sprintf("  %s: %s\n", k, if (k %in% names(a)) paste("lo", a[k]) else paste("hi", b[k])))
}
