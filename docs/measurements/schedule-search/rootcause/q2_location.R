# q2_location.R: where the error of a committed schedule comes from, from runs that differ
# in one region only. Moves in eps; a bisected class's error is -4/3 of its move (square law).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
v <- function(nm, dir = NULL) { id <- TAB$id[TAB$name == nm & TAB$grad & (is.null(dir) | grepl(if (is.null(dir)) "" else dir, TAB$dir))][1]; qof(id)[Q] / EPS }
r2 <- function(x) sqrt(mean(x^2))
on <- function(x) sum(x * M_unit)
fmt <- function(x) sprintf("rms %.3f | along M %+.2f, off-M rms %.3f | lnJ %+.3f | top %s", r2(x), on(x), r2(x - on(x) * M_unit), x["lnJ"],
  paste(sprintf("%s %+.2f", names(x)[order(-abs(x))][1:3], x[order(-abs(x))][1:3]), collapse = ", "))
cat("== (a) one interval class of a09's committed dry schedule bisected (X, AG): error share = -4/3 move\n")
for (g in c("L19", "AG")) { base <- if (g == "AG") v("AG_a09c_dry") else v("val_a09_c_dry"); ref <- REF[[if (g == "AG") "AG" else "L19"]]$dry[Q] / EPS; e0 <- base - ref
  cat(sprintf("%s committed error: %s\n", g, fmt(e0))); tot <- 0
  for (k in c("F", "O", "C", "S", "G", "I")) { nm <- sprintf("%s_a09b%s_dry", if (g == "AG") "AG" else "X", k); x <- -4 / 3 * (v(nm) - base); tot <- tot + x
    cat(sprintf("   class %s (n %d): %s | share of |e0|^2 by projection %.0f%%\n", k, TAB$n[TAB$name == nm][1], fmt(x), 100 * sum(x * e0) / sum(e0^2))) }
  nb <- -4 / 3 * (v(sprintf("%s_a09nb_dry", if (g == "AG") "AG" else "X")) - base)
  cat(sprintf("   sum of classes: %s\n   whole halving (nb): %s\n   e0 - sum of classes: %s\n", fmt(tot), fmt(nb), fmt(e0 - tot))) }
cat("\n== (b) edge nodes moved (P, lib19, 1e-4), move from a09's committed run\n")
for (cs in c("dry", "episodic", "long-drought", "dry-flat", "episodic-lma")) { base <- v(sprintf("val_%s_c_%s", if (cs %in% c("long-drought")) "a09p" else "a09", cs))
  ref <- REF$L19[[cs]][Q] / EPS; cat(sprintf("%s a09 c error: %s\n", cs, fmt(base - ref)))
  for (k in c("in3", "in10", "out10", "mid", "insc")) { nm <- sprintf("P_%s_%s", k, cs); if (!nm %in% TAB$name) next; mv <- v(nm) - base
    cat(sprintf("   %-6s move %s | corr(move, a09 err) %+.2f | new err rms %.3f worst %.2f\n", k, fmt(mv), cor(mv, base - ref), r2(v(nm) - ref), max(abs(v(nm) - ref)))) } }
cat("\n== (c) late edges and merged gaps: committed runs of algorithm variants (same case, lib19, 1e-4)\n")
nodes_by_band <- function(S, b1) table(cut(S, c(0, b1, 10, 25, 40), right = FALSE))
for (cs in ALL) { b1 <- PIL[[cs]]$b1; ref <- REF$L19[[cs]][Q] / EPS
  tags <- c("a05t", "a07", "a08", if (cs %in% c("long-drought", "ld-102", "ld-105")) "a09" else "a09")
  for (pr in list(c("a05t", "a09", "late edges kept (a05t) vs dropped (a09)"), c("a07", "a08", "a07 vs a08 (late handling)"), c("a09", "a07", "a09 vs a07 (short gaps merged, late)"))) {
    x <- sprintf("val_%s_c_%s", pr[1], cs); y <- sprintf("val_%s_c_%s", pr[2], cs); if (!all(c(x, y) %in% TAB$name)) next
    lx <- TAB$legacy[TAB$name == x][1]; ly <- TAB$legacy[TAB$name == y][1]; if (lx != ly) next
    Sx <- RR[[byname(x)]]$S; Sy <- RR[[byname(y)]]$S; mv <- v(y) - v(x)
    cat(sprintf("%-12s %-38s nodes %s -> %s | move %s\n", cs, pr[3], paste(nodes_by_band(Sx, b1), collapse = "/"), paste(nodes_by_band(Sy, b1), collapse = "/"), fmt(mv))) } }
