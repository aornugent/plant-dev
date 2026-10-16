# inv.R: one compact table of every saved TF24 stand run with a gradient: its build,
# setting, case, schedule, quantities, cost and per-node outputs. Written to OUT/inv.rds.
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
ST <- file.path(DEV, "schedtest")
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
dirs <- c(file.path(ST, c("adjmap/runs", "placed2/runs", "X_out/runs", "AG_out/runs", "P_out/runs", "E_out/runs",
  "G_out/runs", "R_out/runs", "S_out/runs", "placement/runs", "estimate/runs", "exact/runs", "lumped/runs",
  "lumped_default/runs", "probe/runs")), file.path(DEV, c("node_rule/ladder/runs", "pf_nodes/runs")), file.path(ST, "JT_out"))
case_name <- function(regime, seed, trait) {
  key <- paste(regime, seed, trait)
  switch(key, "episodic 31 " = "episodic", "episodic 31 lma=0.25" = "episodic-lma", "dry 31 " = "dry",
    "dry 31 root_P50=0.2" = "dry-p50", "dry-flat 31 " = "dry-flat", "long-wet 31 " = "long-wet",
    "long-wet 31 a_dG2=0.25" = "wet-adG2", "long-drought 31 " = "long-drought", "long-drought 102 " = "ld-102",
    "long-drought 105 " = "ld-105", NA_character_) }
rows <- list(); runs <- list()
for (d in dirs) for (f in list.files(d, "\\.rds$", full.names = TRUE)) {
  if (grepl("partial|killed", f)) next
  x <- tryCatch(readRDS(f), error = function(e) NULL)
  if (!is.list(x) || is.null(x$stand) || is.null(x$setting) || is.null(x$node_times)) next
  s <- x$setting; e <- s$env; g <- function(k) if (k %in% names(e)) unname(e[[k]]) else ""
  lib <- basename(g("LIB")); if (lib == "") lib <- "lib"; if (g("KNOTS") == "0") lib <- paste0(lib, "+k0")
  el <- x$stand$elasticity
  nm <- sub("\\.rds$", "", basename(f)); id <- paste0(sub(paste0(DEV, "/"), "", dirname(f)), "/", nm)
  rows[[id]] <- data.frame(id = id, name = nm, dir = sub(paste0(DEV, "/"), "", dirname(f)), regime = s$regime, seed = s$seed,
    trait = g("TRAIT_REL"), case = case_name(s$regime, s$seed, g("TRAIT_REL")), lib = lib, tol = s$tol, atol = if (is.null(s$atol)) NA else s$atol,
    share = g("SHARE"), split = g("SPLIT"), hmax = g("HMAX"), pin = basename(g("PIN")), coarse = basename(g("COARSE")), mode = if (is.null(x$mode)) "" else x$mode,
    n = length(x$node_times), J = x$stand$J, rows = if (is.null(x$stand$rows)) NA else x$stand$rows, steps = length(x$stand$times),
    cpu = if (is.null(x$stand$cpu)) NA else x$stand$cpu, sweep_cpu = if (is.null(x$sweep_cpu)) NA else x$sweep_cpu,
    grad = !is.null(el), dropped = length(x$dropped), finished = !is.null(x$finished), stringsAsFactors = FALSE)
  nd <- x$stand$nodes
  runs[[id]] <- list(S = x$node_times, el = el, J = x$stand$J,
    nrr = if (!is.null(nd$nrr)) nd$nrr, est = if (!is.null(nd$establishment)) nd$establishment,
    creation = if (!is.null(x$stand$creation)) as.data.frame(x$stand$creation))
  rm(x); if (length(rows) %% 100 == 0) { cat(length(rows), "\n"); gc() }
}
tab <- do.call(rbind, rows); rownames(tab) <- NULL
saveRDS(list(tab = tab, runs = runs), file.path(OUT, "inv.rds"))
print(table(tab$lib, tab$tol)); print(table(tab$case, tab$lib))
