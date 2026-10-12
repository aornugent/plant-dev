# Hybrid certificate: H's estimate (central drops e g(l), midpoints e/3) against H's
# error from the reference and from the map on B = bisect(G); rows against B's.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
run <- function(name) { f <- file.path(D, "schedtest/adjmap/runs", paste0(name, ".rds")); if (file.exists(f)) readRDS(f) }
lj <- function(o) log(o$stand$J); x2 <- function(m, f) { a <- lj(readRDS(m)); b <- lj(readRDS(f)); b + (b - a) / 3 }
ref <- list(episodic = x2(file.path(NR, "u429_episodic.rds"), file.path(P, "u857_episodic.rds")), dry = x2(file.path(NR, "u215_dry.rds"), file.path(NR, "u429_dry.rds")),
  `long-wet` = x2(file.path(NR, "u215_long-wet.rds"), file.path(NR, "u429_long-wet.rds")), `long-drought` = x2(file.path(PF, "ld_D_u215.rds"), file.path(PF, "ld_D_u429.rds")))
for (cs in list(c("u108e_episodic", "episodic", "hier_u108e_episodic_p1"), c("dy_dry", "dry", "hier_dy_dry_p1"), c("dy_long-wet", "long-wet", "hier_dy_long-wet_p1"), c("dy_long-drought", "long-drought", "hier_dy_long-drought_p1"))) {
  xh <- run(paste0("hyb_", cs[1])); xb <- run(cs[3]); if (is.null(xh$soil)) next
  h <- xh$node_times; j <- xh$dropped; b <- nd(xh); e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(xh$light + xh$soil) / xh$stand$J
  g <- readRDS(file.path(D, "schedtest/hier", paste0(cs[3], "_G.rds"))); isg <- round(h[j], 9) %in% round(g, 9)
  l <- (h[j] - h[j - 1]) / (h[j + 1] - h[j - 1]); f <- ifelse(isg, (l^3 + (1 - l)^3) / (3 * l * (1 - l)), 1 / 3)
  cat(sprintf("%-16s H %d nodes %5.0fk rows (B %5.0fk) | H's error %+.3f | estimate %+.3f (central %+.3f, midpoints %+.3f) eps\n", cs[1], length(h), xh$stand$rows / 1e3,
    xb$stand$rows / 1e3, (lj(xh) - ref[[cs[2]]]) / .025, sum(e * f) / .025, sum((e * f)[isg]) / .025, sum((e * f)[!isg]) / .025)) }
