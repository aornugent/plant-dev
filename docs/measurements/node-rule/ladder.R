# Item 6's ladders (prereg.txt, "The ladders", 2026-10-07): L1 the square law, L2
# the companion, L3 the quarter-spacing move, per record and role.
#   DEV=... Rscript ladder.R
D <- Sys.getenv("DEV")
O <- file.path(D, "node_rule", "ladder", "runs")
G <- file.path(D, "soil_alone", "gates", "runs")
here <- if (nzchar(Sys.getenv("PLANT_DEV"))) Sys.getenv("PLANT_DEV") else "/home/user/plant-dev"
eps <- read.csv(file.path(here, "docs/measurements/eps.csv"))
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait & eps$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
structural <- c("S_D", "a_f3")
run <- function(dir, name) {
  f <- file.path(dir, paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)
}
# ln J and each elasticity of one role, named by trait.
quantities <- function(o, role) {
  x <- o[[role]]
  if (is.null(x$elasticity)) return(NULL)
  e <- unname(x$elasticity)
  names(e) <- sub("^1\\.", "", names(x$elasticity))
  c(`ln J` = log(x$J), e[!names(e) %in% structural])
}
extrapolated <- function(m, f) f + (f - m) / 3
rows_of <- function(o) {
  n <- length(o$stand$times)
  sum(vapply(o$stand$times[-n], function(t) sum(o$node_times <= t), 0))
}
ladders <- list(
  `long-wet` = c(c = "u108_long-wet", m = "u215_long-wet", f = "u429_long-wet",
                 sm = "s215_long-wet", sf = "s429_long-wet"),
  dry = c(c = "u108_dry", m = "u215_dry", f = "u429_dry", sm = "s215_dry", sf = "s429_dry"),
  episodic = c(c = "u108_episodic", m = "u215_episodic", f = "u429_episodic",
               sm = "s215_episodic", sf = "s429_episodic"),
  constant = c(c = "c_Gbf8", m = "c_Gbf16", f = "c_Gbf32", sm = "cs_Gbf16", sf = "cs_Gbf32"))
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"

for (rec in names(ladders)) {
  o <- lapply(ladders[[rec]], function(n) run(O, n))
  missing <- names(o)[vapply(o, is.null, TRUE)]
  cat(sprintf("== %s: rungs %s\n", rec, paste(ladders[[rec]], collapse = ", ")))
  if (length(missing)) {
    cat("   not run yet:", paste(ladders[[rec]][missing], collapse = ", "), "\n")
    next
  }
  b <- run(G, paste0("b5_", rec)); n <- run(G, paste0("b5n_", rec))
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    q <- lapply(o, quantities, role = role)
    if (any(vapply(q, is.null, TRUE))) {
      cat(sprintf("   %-8s a rung has no gradient\n", r)); next
    }
    keep <- Reduce(intersect, lapply(q, names))
    q <- lapply(q, function(x) x[keep])
    e <- vapply(keep, function(k) eps_of(r, if (k == "ln J") "ln J" else k), 0)
    nudge <- abs(quantities(n, role)[keep] - quantities(b, role)[keep])
    nudge[is.na(nudge)] <- 0
    resolved <- abs(q$m - q$f) >= 3 * nudge
    ratio <- (q$c - q$m) / (q$m - q$f)
    ref <- extrapolated(q$m, q$f)
    companion <- ((q$c - q$m) / 3) / (q$m - ref)
    move <- abs(extrapolated(q$sm, q$sf) - ref) / e
    k <- resolved & is.finite(ratio)
    L1 <- median(ratio[k]) >= 3 && median(ratio[k]) <= 5.3 && mean(ratio[k] < 0) < 0.1
    L2 <- median(companion[k]) >= 0.8 && median(companion[k]) <= 1.25
    L3 <- all(move < 1 / 3)
    cat(sprintf("   %-8s %d of %d resolved; L1 median ratio %.2f, %.0f%% negative  %s; L2 median companion %.2f  %s\n",
                r, sum(k), length(k), median(ratio[k]), 100 * mean(ratio[k] < 0), verdict(L1),
                median(companion[k]), verdict(L2)))
    over <- keep[move >= 1 / 3]
    cat(sprintf("            L3 the move: largest %.3f eps (%s)%s  %s\n", max(move),
                keep[which.max(move)],
                if (length(over)) paste0("; over eps/3: ", paste(over, collapse = ", ")) else "",
                verdict(L3)))
  }
  rows <- vapply(o, rows_of, 0)
  secs <- vapply(o, function(x) sum(vapply(x$phases, function(p) p$secs, 0)), 0)
  cat(sprintf("   rows %s; seconds %s\n", paste(sprintf("%s %.0f", names(rows), rows), collapse = ", "),
              paste(sprintf("%s %.0f", names(secs), secs), collapse = ", ")))
}
