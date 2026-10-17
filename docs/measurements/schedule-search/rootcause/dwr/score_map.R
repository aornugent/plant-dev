# score_map.R CASE TAG: one map replay (dwr/runs/map_TAG_CASE.rds) of the saved run named in
# dwr/sched/drop_TAG_CASE.rds. Per region (and era): the virtual move D = own + field in eps of
# ln J (own exact from the stored weights and fates; field = the drop columns / J), the light
# and soil channels, the field by time band, and the region error estimate e = D/3.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
a <- commandArgs(TRUE); cs <- a[1]; tag <- a[2]
dr <- readRDS(file.path(DW, "sched", sprintf("drop_%s_%s.rds", tag, cs)))
m <- readRDS(file.path(DW, "runs", sprintf("map_%s_%s.rds", tag, cs))); base <- readRDS(run_file(dr$run))
stopifnot(identical(as.integer(m$dropped), as.integer(dr$drop)))
g0 <- unname(base$stand$gradient); g1 <- unname(m$stand$gradient)
cat(sprintf("guard: J identical %s (rel %.1e); 50 trait columns identical %s (max rel %.1e); sweep0 vs saved gradient max rel %.1e\n",
  identical(m$stand$J, base$stand$J), m$stand$J / base$stand$J - 1, identical(g0, g1), max(abs(g1 / g0 - 1)),
  if (!is.null(m$sweep0_gradient)) max(abs(unname(m$sweep0_gradient) / g0 - 1)) else NA))
cat(sprintf("cost: nodes %d, rows %.0f, forward %.0f s, plain sweep %s s, map sweep %.0f s (x%.2f); saved run: rows %.0f, forward %.0f s, sweep %.0f s\n",
  length(dr$S), m$stand$rows, m$stand$cpu, format(round(m$sweep0_cpu %||% NA)), m$sweep_cpu, m$sweep_cpu / (m$sweep0_cpu %||% NA), base$stand$rows, base$stand$cpu, base$sweep_cpu))
J <- m$stand$J; u <- 0.025
L <- m$light / J / u; Sl <- m$soil / J / u  # bands x drops, eps of ln J
own_of <- function(k) interp_part(base, dr$S[-dr$drop[k]]) / u
rows <- list()
for (g in c(sort(unique(dr$region)), sort(unique(dr$era[dr$region == "I"])), "all")) {
  k <- if (g == "all") rep(TRUE, length(dr$drop)) else if (g %in% dr$region) dr$region == g else dr$era == g
  own <- own_of(k); li <- sum(L[, k]); so <- sum(Sl[, k]); D <- own + li + so
  rows[[g]] <- data.frame(region = g, drops = sum(k), own = own, light = li, soil = so, field = li + so, D = D, e = D / 3,
                          t_ge10 = sum(L[7:8, k] + Sl[7:8, k]) / (li + so))
}
tab <- do.call(rbind, rows)
cat(sprintf("%s %s: virtual move by region (eps of ln J); e = D/3\n", cs, tag))
print(format(tab, digits = 3), row.names = FALSE)
bands <- sapply(c("I", "F"), function(g) { k <- dr$region == g; if (!any(k)) rep(NA, nrow(L)) else rowSums(L[, k, drop = FALSE] + Sl[, k, drop = FALSE]) })
rownames(bands) <- c("0-0.5", "0.5-1", "1-2", "2-3", "3-5", "5-10", "10-20", "20-40")
cat("field by time band (y):\n"); print(round(t(bands), 3))
saveRDS(list(tab = tab, bands = bands, per_drop = data.frame(b = dr$S[dr$drop], region = dr$region, era = dr$era, light = colSums(L), soil = colSums(Sl))),
        file.path(DW, sprintf("score_%s_%s.rds", tag, cs)))
