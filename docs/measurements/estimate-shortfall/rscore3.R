# Round 3: each pass against the reference, resident ln J and elasticities in eps,
# with the pass's own estimate and cumulative rows.  Rscript rscore3.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
AR <- file.path(D, "schedtest/adjmap/runs"); Q <- file.path(D, "schedtest/placed2/runs")
resq <- function(o) { x <- o$stand; e <- unname(x$elasticity); names(e) <- sub("^1\\.", "", names(x$elasticity))
  v <- c(`ln J` = log(x$J), e[!names(e) %in% structural]); names(v) <- paste("resident", names(v)); v }
pair <- function(m, f) { a <- resq(m); b <- resq(f); k <- intersect(names(a), names(b)); extrap(a[k], b[k]) }
ref_of <- function(rec, tag) switch(paste(if (grepl("lma$", tag)) "s16lma" else "s16", rec),
  `s16 episodic` = pair(rd(NR, "u429_episodic"), rd(P, "u857_episodic")),
  `s16 dry` = pair(rd(NR, "u215_dry"), rd(NR, "u429_dry")),
  `s16 long-wet` = pair(rd(NR, "u215_long-wet"), rd(NR, "u429_long-wet")),
  `s16lma episodic` = pair(rd(Q, "m_lma1252_episodic"), rd(Q, "m_lma1254_episodic")),
  `s16 long-drought` = pair(rd(PF, "ld_D_u215"), rd(PF, "ld_D_u429")),
  `s16 constant` = pair(rd(Q, "e_cF2_constant"), rd(Q, "e_cF4_constant")))
cases <- c(lapply(c("episodic", "dry", "long-wet", "long-drought", "constant"), c, "s16"), list(c("episodic", "s16lma")),
  lapply(c("episodic", "dry"), c, "dft"), lapply(c("episodic", "dry", "long-wet"), c, "u108e"), list(c("episodic", "u108elma")))
for (cs in cases) {
  rec <- cs[1]; tag <- cs[2]; ref <- ref_of(rec, tag); cum <- 0
  if (is.null(rd(AR, sprintf("ref_%s_%s_p0", tag, rec)))) next
  cat(sprintf("\n== %s %s\n", rec, tag))
  for (k in 0:6) { o <- rd(AR, sprintf("ref_%s_%s_p%d", tag, rec, k)); if (is.null(o) || is.null(o$stand$elasticity)) break
    q <- resq(o); kk <- intersect(names(q), names(ref)); kk <- kk[!endsWith(kk, nuisance)]
    e <- (q[kk] - ref[kk]) / eps_vec(kk); cum <- cum + o$stand$rows
    b <- nd(o); j <- o$dropped; pe <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(o$light + o$soil) / o$stand$J
    cat(sprintf("  pass %d %4d nodes %6.0fk rows (sum %6.0fk) | ln J err %+.2f est %+.2f | max %.2f (%s), median %.3f, > eps %d of %d\n",
      k, length(o$node_times), o$stand$rows / 1e3, cum / 1e3, e[["resident ln J"]], sum(pe) / 3 / 0.025, max(abs(e)),
      sub("resident ", "", names(which.max(abs(e)))), median(abs(e)), sum(abs(e) > 1), length(e))) }
}
