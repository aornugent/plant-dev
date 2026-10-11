# Each refinement pass against the reference: resident ln J and elasticities in eps.
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
AR <- file.path(D, "schedtest/adjmap/runs"); Q <- file.path(D, "schedtest/placed2/runs")
refs$dry <- list(m = rd(NR, "u215_dry"), f = rd(NR, "u429_dry")); refs$`long-wet` <- list(m = rd(NR, "u215_long-wet"), f = rd(NR, "u429_long-wet"))
resq <- function(o) { x <- o$stand; e <- unname(x$elasticity); names(e) <- sub("^1\\.", "", names(x$elasticity))
  v <- c(`ln J` = log(x$J), e[!names(e) %in% structural]); names(v) <- paste("resident", names(v)); v }
ref_of <- function(rec, tag) {
  if (tag == "th0") { rf <- refs[[rec]]; a <- resq(rf$m); b <- resq(rf$f); k <- intersect(names(a), names(b)); return(extrap(a[k], b[k])) }
  a <- resq(rd(Q, paste0("m_", tag, "2_", rec))); b <- resq(rd(Q, paste0("m_", tag, "4_", rec))); extrap(a, b)
}
for (cs in list(c("episodic", "th0b"), c("dry", "th0b"), c("long-wet", "th0b"), c("episodic", "lma125b"))) {
  rec <- cs[1]; tag <- cs[2]; ref <- ref_of(rec, sub("b$", "", tag))
  cat(sprintf("\n== %s %s\n", rec, tag))
  show <- function(nm, o) { if (is.null(o)) return(); q <- resq(o); k <- intersect(names(q), names(ref)); k <- k[!endsWith(k, nuisance)]
    e <- (q[k] - ref[k]) / eps_vec(k)
    cat(sprintf("  %-12s %4d nodes %8.0fk rows | ln J %+.2f | max %.2f, median %.3f, > eps %d of %d\n", nm, length(o$stand$nodes$birth),
        (if (!is.null(o$stand$rows)) o$stand$rows else rows_of(o)) / 1e3, e[["resident ln J"]], max(abs(e)), median(abs(e)), sum(abs(e) > 1), length(e))) }
  for (k in 0:5) show(sprintf("pass %d", k), rd(AR, sprintf("ref_%s_%s_p%d", tag, rec, k)))
  for (L in c("", "2", "4")) show(paste0("ladder L", c("0", "1", "2")[match(L, c("", "2", "4"))]), rd(Q, paste0("m_", sub("b$", "", tag), L, "_", rec)))
}
