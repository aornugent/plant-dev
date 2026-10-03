# Per-recording tape statistics from the tapestats shim, summarised per sweep:
# totals by phase, and per-member costs as the slope of a step recording's size
# and time against the members it carries.
#   Rscript tape_summary.R out/tape5_guard.tsv [out/tape5_spread.tsv ...]
N_PARAM <- 50   # trait inputs registered beside the state; checked below
ENV_W <- 10     # the patch's width with no node
NODE_W <- 9     # state entries per node

summarise <- function(path) {
  d <- read.delim(path)
  tapes <- d[d$kind == "tape", ]
  r <- d[d$kind == "rec", ]
  # The sweep is the tape with the most recordings; the census seeds are a
  # one-recording tape of their own.
  sweep_tape <- as.integer(names(which.max(table(r$tape))))
  seeds <- r[r$tape != sweep_tape, ]
  r <- r[r$tape == sweep_tape, ]
  r$width <- r$inputs - N_PARAM
  r$nodes <- (r$width - ENV_W) / NODE_W
  stopifnot(all(abs(r$nodes - round(r$nodes)) < 1e-9))
  m <- ave(r$statements, r$width, FUN = max)
  r$kind2 <- ifelse(r$statements < 0.4 * m, "insertion", "step")
  st <- r[r$kind2 == "step", ]
  ins <- r[r$kind2 == "insertion", ]
  prev <- c("none", head(r$kind2, -1))
  gap_ins <- sum(r$gap_s[r$kind2 == "insertion" | prev == "insertion"])
  gap_step <- sum(r$gap_s[!(r$kind2 == "insertion" | prev == "insertion")])
  tw <- tapes[tapes$tape == sweep_tape, ]
  fit <- function(y) coef(lm(y ~ st$nodes))
  rows <- sum(st$nodes)
  list(
    path = path,
    tape_wall = tw$rec_s, tape_cpu = tw$sweep_s,
    seed_tape = c(statements = sum(seeds$statements), rec_s = sum(seeds$rec_s),
                  sweep_s = sum(seeds$sweep_s)),
    n_step = nrow(st), n_ins = nrow(ins), rows = rows,
    totals = c(step_rec = sum(st$rec_s), step_sweep = sum(st$sweep_s),
               step_local = sum(st$local_s),
               ins_rec = sum(ins$rec_s), ins_sweep = sum(ins$sweep_s),
               clear = sum(r$clear_s), gap_at_insertions = gap_ins,
               gap_between_steps = gap_step),
    statements = c(total_step = sum(st$statements), per_row = sum(st$statements) / rows,
                   slope = fit(st$statements)),
    operations = c(total_step = sum(st$operations), per_row = sum(st$operations) / rows,
                   slope = fit(st$operations)),
    local = c(n_per_row = sum(st$local_n) / rows, stmts_per_row = sum(st$local_stmts) / rows,
              slope_n = fit(st$local_n), slope_stmts = fit(st$local_stmts)),
    rec_us = 1e6 * fit(st$rec_s), sweep_us = 1e6 * fit(st$sweep_s),
    max_bytes = max(r$bytes), max_nodes = max(r$nodes),
    bytes_slope = fit(st$bytes),
    per_ins = c(rec_ms = 1e3 * mean(ins$rec_s),
                gap_ms = 1e3 * gap_ins / max(nrow(ins), 1)))
}

for (p in commandArgs(TRUE)) {
  s <- summarise(p)
  cat(sprintf("== %s\n", s$path))
  cat(sprintf("sweep tape: wall %.2f s, process cpu %.2f s; %d step recordings (%.0f rows), %d insertion recordings; census seeds %.0f statements, %.3f s\n",
              s$tape_wall, s$tape_cpu, s$n_step, s$rows, s$n_ins,
              s$seed_tape[["statements"]], s$seed_tape[["rec_s"]] + s$seed_tape[["sweep_s"]]))
  tot <- s$totals
  cat("wall seconds by phase (share of the sweep tape's wall):\n")
  print(round(rbind(seconds = tot, share = tot / s$tape_wall), 4))
  cat(sprintf("unaccounted (between phases, outside tape calls): %.3f s\n", s$tape_wall - sum(tot) + tot[["step_local"]]))
  cat(sprintf("step recording per row: %.0f statements, %.0f operations; slope per node per step %.0f statements, %.0f operations (intercept %.0f, %.0f)\n",
              s$statements[["per_row"]], s$operations[["per_row"]],
              s$statements[["slope.st$nodes"]], s$operations[["slope.st$nodes"]],
              s$statements[["slope.(Intercept)"]], s$operations[["slope.(Intercept)"]]))
  cat(sprintf("per member evaluation (slope / 6): %.0f statements, %.0f operations, %.2f us recording, %.2f us reverse; local sweeps %.2f of %.1f statements each\n",
              s$statements[["slope.st$nodes"]] / 6, s$operations[["slope.st$nodes"]] / 6,
              s$rec_us[[2]] / 6, s$sweep_us[[2]] / 6,
              s$local[["slope_n.st$nodes"]] / 6,
              s$local[["slope_stmts.st$nodes"]] / max(s$local[["slope_n.st$nodes"]], 1)))
  cat(sprintf("per step fixed (intercept): %.0f us recording, %.0f us reverse\n",
              s$rec_us[[1]], s$sweep_us[[1]]))
  cat(sprintf("largest recording %.1f MB at %d nodes; bytes per node per step %.0f\n",
              s$max_bytes / 2^20, s$max_nodes, s$bytes_slope[[2]]))
  cat(sprintf("per insertion row: %.2f ms recording, %.2f ms around it (rebinds, be_at_step)\n",
              s$per_ins[["rec_ms"]], s$per_ins[["gap_ms"]]))
  saveRDS(s, sub("\\.tsv$", "_summary.rds", p))
}
