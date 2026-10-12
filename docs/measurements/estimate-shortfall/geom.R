# The drop map's estimate with each panel's geometry: a dropped node at fraction l of
# its merged panel gives err(P) = e * (l^3 + (1-l)^3) / (3 l (1-l)) under an h^3 error
# per interval; the plain estimate uses e / 3 (l = 1/2). Against the error, and 4/3 (P-B).
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap/lib.R", local = TRUE) |> try(silent = TRUE)
run <- function(name) { f <- file.path(D, "schedtest/adjmap/runs", paste0(name, ".rds")); if (file.exists(f)) readRDS(f) }
lj <- function(o) log(o$stand$J)
ref <- list(episodic = { a <- lj(readRDS(file.path(NR, "u429_episodic.rds"))); b <- lj(readRDS(file.path(P, "u857_episodic.rds"))); b + (b - a) / 3 },
            dry = { a <- lj(readRDS(file.path(NR, "u215_dry.rds"))); b <- lj(readRDS(file.path(NR, "u429_dry.rds"))); b + (b - a) / 3 },
            `long-wet` = { a <- lj(readRDS(file.path(NR, "u215_long-wet.rds"))); b <- lj(readRDS(file.path(NR, "u429_long-wet.rds"))); b + (b - a) / 3 },
            `long-drought` = { a <- lj(readRDS(file.path(PF, "ld_D_u215.rds"))); b <- lj(readRDS(file.path(PF, "ld_D_u429.rds"))); b + (b - a) / 3 })
est <- function(x) { b <- nd(x); j <- x$dropped; e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J
  t <- x$node_times; l <- (t[j] - t[j - 1]) / (t[j + 1] - t[j - 1]); g <- (l^3 + (1 - l)^3) / (3 * l * (1 - l))
  c(plain = sum(e) / 3, geom = sum(e * g), lmin = min(pmin(l, 1 - l))) }
for (tag in c("u108e", "s16", "dft")) for (rec in names(ref)) for (k in 0:6) {
  x <- run(sprintf("ref_%s_%s_p%d", tag, rec, k)); if (is.null(x) || is.null(x$soil)) next
  s <- est(x); cat(sprintf("%-6s %-12s p%d: err %+.3f | plain %+.3f | geometric %+.3f eps | smallest l %.3f\n", tag, rec, k, (lj(x) - ref[[rec]]) / .025, s["plain"] / .025, s["geom"] / .025, s["lmin"])) }
