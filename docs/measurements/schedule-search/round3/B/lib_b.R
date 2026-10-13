# Shared readers for the edge-thinning study: the pilot's edges with their spell and gap,
# and every saved drop map's per-node move of ln J (in eps), tagged edge or interior.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib", .libPaths()))
suppressMessages(source("/home/user/plant-dev/harness/schedule/lattice.R"))
AR <- file.path(DEV, "schedtest/adjmap/runs"); LOC <- file.path(DEV, "schedtest/loc")
EPS_J <- 0.025; H <- 39.6
patches <- plant::Weibull_Disturbance_Regime(40)
edge_table <- function(cs) {
  pe <- pilot_edges(cs); e <- sort(pe$edges); n <- length(e)
  opening <- pe$shut(e - 1e-6) > 0.5
  prev <- c(0, e[-n]); nxt <- c(e[-1], H)
  gap <- ifelse(opening, e - prev, nxt - e) * 365
  spell <- ifelse(opening, nxt - e, e - prev) * 365
  px <- readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand$nodes
  off <- px$nrr * vapply(px$birth, patches$density, 0); ok <- off > 0
  lo <- approx(px$birth[ok], log(off[ok]), e, rule = 2)$y
  bo <- px$birth[ok]; med <- median(log(off[ok])[bo < 25 & pe$shut(bo) < 0.5])
  data.frame(e = e, opening = opening, gap = gap, spell = spell, loff = lo - med, b1 = pe$b1)
}
case_of_run <- function(f, y) { reg <- y$setting$regime
  if (grepl("lma", f)) return(if (reg == "episodic") "episodic-lma" else NA)
  if (reg %in% names(CASES)) reg else NA }
# Per dropped node: birth, neighbour spacings (y), move of ln J in eps, edge index or NA.
map_moves <- function(f, cs, E) {
  y <- readRDS(file.path(AR, f)); S <- y$node_times; j <- y$dropped
  nn <- y$stand$nodes; m <- min(length(nn$establishment), length(nn$nrr))
  b <- data.frame(birth = nn$birth[1:m], w = nn$establishment[1:m], offspring = nn$nrr[1:m] * vapply(nn$birth[1:m], patches$density, 0))
  l <- (b$birth[j] - b$birth[j - 1]) / (b$birth[j + 1] - b$birth[j - 1])
  own <- -b$w[j] * (b$offspring[j] - (1 - l) * b$offspring[j - 1] - l * b$offspring[j + 1]) / sum(b$w * b$offspring)
  fld <- (colSums(y$light) + colSums(y$soil)) / y$stand$J
  k <- vapply(S[j], function(s) { i <- which(abs(E$e - s) < 1e-6); if (length(i)) i[1] else NA_integer_ }, 0L)
  data.frame(run = sub("\\.rds$", "", f), case = cs, birth = S[j], h1 = S[j] - S[j - 1], h2 = S[j + 1] - S[j],
             m = (own + fld) / EPS_J, own = own / EPS_J, edge = k)
}
band_of <- function(b, b1) factor(ifelse(b < b1 - 1e-9, "<b1", ifelse(b < 10, "b1-10", ifelse(b < 20, "10-20", ifelse(b < 25, "20-25", ">25")))),
  levels = c("<b1", "b1-10", "10-20", "20-25", ">25"))
all_maps <- function() {
  out <- list(); ET <- lapply(setNames(names(CASES), names(CASES)), edge_table)
  for (f in list.files(AR, "^ref_.*_p[0-9]\\.rds$")) { y <- readRDS(file.path(AR, f))
    if (!identical(y$mode, "map") || !length(y$dropped)) next
    cs <- case_of_run(f, y); if (is.na(cs)) next
    out[[f]] <- map_moves(f, cs, ET[[cs]]) }
  list(M = do.call(rbind, out), ET = ET) }
# Open-weighted panel functional: 6 * integral over the open part of [a, c] of
# (t - a)(c - t) dt, in y^3; a fully open panel gives h^3. Open spells from the pilot's edges.
open_segs <- function(cs) { pe <- pilot_edges(cs); e <- sort(c(0, pe$edges, H)); m <- (head(e, -1) + e[-1]) / 2
  o <- pe$shut(m) < 0.5; cbind(lo = head(e, -1)[o], hi = e[-1][o]) }
Eopen <- function(a, c, seg) { F <- function(t) -t^3 / 3 + (a + c) * t^2 / 2 - a * c * t
  lo <- pmax(seg[, 1], a); hi <- pmin(seg[, 2], c); k <- hi > lo; 6 * sum(F(hi[k]) - F(lo[k])) }
# The move of ln J (per unit d) of merging the panels of S between kept nodes a < c.
Emerge <- function(S, a, c, seg) { s <- S[S >= a - 1e-12 & S <= c + 1e-12]
  Eopen(a, c, seg) - sum(vapply(seq_len(length(s) - 1), function(i) Eopen(s[i], s[i + 1], seg), 0)) }
