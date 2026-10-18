# fr_data.R: the saved runs the frontier screen reads, per case, as errors against the
# reference ladder (eps units) and CPU: canonical scale-1 fits (libS, in memory), round 5's
# G5 / G5o / G5b, and the half-scale loops' levels 0-2 with level 0's replay.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
S1 <- file.path(SP, "refine/s1"); S05 <- file.path(SP, "refine/s05"); R5R <- file.path(SP, "deep/rootcause/evidence/r5/runs")
FIVE <- c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")
rd <- function(f) if (file.exists(f)) readRDS(f)
cpu_of <- function(x) x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)
fr_case <- function(cs) {
  R <- ref_ladder(cs); E <- function(q) (q[Q] - R$ref[Q]) / EPS[Q]
  out <- list(case = cs, own = R$own)
  f <- rd(file.path(S1, paste0(cs, ".rds"))); h <- f$history[[1]]
  out$s1 <- list(err = E(h$answer), e = h$estimate[Q], nodes = h$nodes, cpu = rowSums(f$costs))
  g <- rd(file.path(R5R, sprintf("G5_%s.rds", cs))); o <- rd(file.path(R5R, sprintf("G5o_%s.rds", cs))); b <- rd(file.path(R5R, sprintf("G5b_%s.rds", cs)))
  out$r5 <- list(err = E(qv(g)), e = (qv(o) - qv(g)) / 3 / EPS, short = 4 / 3 * (qv(g) - qv(b)) / EPS, nodes = length(g$node_times),
                 rows = c(run = g$stand$rows, replay = o$stand$rows, bisect = b$stand$rows), cpu = c(run = cpu_of(g), replay = cpu_of(o)))
  d <- file.path(S05, cs); lv <- list()
  for (k in 0:2) { x <- rd(file.path(d, sprintf("level%d.rds", k))); if (is.null(x)) next
    lv[[k + 1]] <- list(err = E(qv(x)), nodes = length(x$node_times), rows = x$stand$rows, cpu = cpu_of(x), steps = length(x$stand$times)) }
  r <- rd(file.path(d, "level0_replay.rds")); fs <- rd(file.path(d, "first.rds"))
  out$s05 <- list(levels = lv, replay = list(err = E(qv(r)), rows = r$stand$rows, cpu = cpu_of(r)), first_cpu = cpu_of(fs))
  out }
FR <- setNames(lapply(FIVE, fr_case), FIVE)
saveRDS(FR, file.path(SP, "frontier/fr_data.rds"))
