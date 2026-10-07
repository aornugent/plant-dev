# The pilot's cost against the harness's pilot and the runs it serves, in accepted
# rows (prereg.txt here, results).
#   DEV=... Rscript cost.R
D <- Sys.getenv("DEV")
G <- file.path(D, "soil_alone", "gates", "runs")
rows_of <- function(o) {
  n <- length(o$stand$times)
  sum(vapply(o$stand$times[-n], function(t) sum(o$node_times <= t), 0))
}
for (r in c("constant", "long-wet", "episodic", "dry", "long-drought")) {
  w <- readRDS(file.path(D, "window_pilot", sprintf("w_%s.rds", r)))
  h <- readRDS(file.path(D, "window", "runs",
                         sprintf("pilot_%s_%s_1e-3.rds", r, if (r == "constant") "Gb" else "u54")))$stand
  # The harness counted every attempt; its accepted rows drop the rejected ones.
  a <- h$attempts
  accepted <- h$member_steps * a[["accepted"]] /
    (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]])
  p <- readRDS(file.path(D, "window_pilot", "runs", sprintf("p7_%s.rds", r)))
  cat(sprintf("%-12s pilot %6.0f rows, %.2f of the harness pilot's %6.0f, %.2f of p7's %6.0f\n", r,
              attr(w, "pilot")$rows, attr(w, "pilot")$rows / accepted, accepted,
              attr(w, "pilot")$rows / rows_of(p), rows_of(p)))
}
# What the soil stepped alone saves a forward, at the gates' setting.
for (r in c("constant", "long-drought", "episodic")) {
  b <- readRDS(file.path(G, sprintf("bnd_%s.rds", r)))
  a <- readRDS(file.path(G, sprintf("alone_%s.rds", r)))
  cat(sprintf("%-12s the soil alone: %6.0f rows against %6.0f, %.2f\n", r, rows_of(a), rows_of(b),
              rows_of(a) / rows_of(b)))
}
