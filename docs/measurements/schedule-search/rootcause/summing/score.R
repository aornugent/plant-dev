# score.R [CASE ...]: every summing run against the nested reference of its case (H2, H4
# trapezium on lib1, Richardson: H4 + (H4 - H2)/3), in eps; the reference against the
# lib19-class one (common.R); negative node weights; rows and cpu; the region split; the
# ladder; the jitter pair. Writes score.rds.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R"))
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
LAY <- readRDS(file.path(SU, "sched", "layout.rds"))
CS <- commandArgs(TRUE); if (!length(CS)) CS <- c("dry", "episodic-lma", "long-wet", "dry-flat", "dry-p50")
rd <- function(n, cs) { f <- file.path(SU, "runs", sprintf("%s_%s.rds", n, cs)); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
qv <- function(x) quantities(x)[Q] / EPS
r2 <- function(x) sqrt(mean(x^2)); onM <- function(e) sum(e * M_unit[names(e)])
fmt <- function(e) { o <- order(-abs(e))[1:3]
  sprintf("rms %.3f worst %.2f | M %+.2f off %.3f | lnJ %+.3f | %s", r2(e), max(abs(e)), onM(e), r2(e - onM(e) * M_unit[names(e)]), e["lnJ"], paste(sprintf("%s %+.2f", names(e)[o], e[o]), collapse = ", ")) }
negw <- function(x, cs, sched = "L") { w <- head(x$stand$nodes$establishment, -1); i <- which(w < 0); if (!length(i)) return("none")
  if (sched != "L") return(sprintf("%d", length(i)))
  pr <- LAY$info[[cs]]$pairs; reg <- vapply(i, function(k) { j <- which(abs(pr$b0 - x$node_times[k]) < 1e-9 | abs(pr$b1 - x$node_times[k]) < 1e-9 | abs(pr$b2 - x$node_times[k]) < 1e-9)
    paste(unique(pr$region[j]), collapse = "+") }, "")
  sprintf("%d (%s; sum %.2g of %.2g)", length(i), paste(names(table(reg)), table(reg), sep = ":", collapse = " "), sum(w[i]), sum(w)) }
QO <- readLines(file.path(SU, "queue.out")); QO <- QO[grepl("^done .* wall [0-9]+$", QO)]
WALL <- setNames(as.numeric(sub(".* wall ", "", QO)), sub("^done (\\S+) .*", "\\1", QO))
cost <- function(x, nm = NULL) sprintf("rows %.0f fwd %.0f s grad %.0f s wall %s s", x$stand$rows, x$stand$cpu, x$sweep_cpu, if (is.null(nm) || is.na(WALL[nm])) "NA" else sprintf("%.0f", WALL[nm]))
out <- list()
for (cs in CS) { cat(sprintf("\n==== %s\n", cs))
  H2 <- rd("H2off", cs); H4 <- rd("H4off", cs); L19 <- REF$L19[[cs]][Q] / EPS
  rich <- if (!is.null(H2) && !is.null(H4)) qv(H4) + (qv(H4) - qv(H2)) / 3 else NULL
  if (!is.null(rich)) { cat(sprintf("reference (H2, H4 trapezium, Richardson) - lib19-class reference: %s\n", fmt(rich - L19)))
    cat(sprintf("   H4 - H2 (trapezium): %s\n", fmt(qv(H4) - qv(H2)))) } else cat("no nested reference yet: errors below are against the lib19-class reference\n")
  ref <- if (is.null(rich)) L19 else rich
  rows <- list()
  for (nm in c("Loff", "Lfounders", "Lfoundersnl", "Lfoundersq", "Lall", "Lallm", "Lallnl", "Lallq", "Lnogap", "Lnogapq", "Lallr", "H2off", "H2all", "H2allm", "H2allq", "H4off", "C2off", "C2all", "C2allm", "C2allq", "P2off", "P2allq", "Lall_t105", "Lallq_t105", "Loff_t105")) { x <- rd(nm, cs); if (is.null(x)) next
    e <- qv(x) - ref; rows[[nm]] <- e
    cat(sprintf("%-10s n %3d | %s | %s | negative weights %s\n", nm, length(x$node_times), fmt(e), cost(x, paste0(nm, "_", cs)), negw(x, cs, sub("(off|all|founders|nogap).*$", "", nm)))) }
  for (j in list(c("Lall_t105", "Lall"), c("Lallq_t105", "Lallq"), c("Loff_t105", "Loff"))) { x <- rd(j[1], cs); y <- rd(j[2], cs); if (is.null(x) || is.null(y)) next
    cat(sprintf("jitter %s - %s: %s\n", j[1], j[2], fmt(qv(x) - qv(y)))) }
  if (!is.null(rich) && !is.null(rows$H2all)) cat(sprintf("H2all - reference: rms %.3f; H2off - reference: rms %.3f\n", r2(rows$H2all), r2(rows$H2off)))
  out[[cs]] <- list(ref = ref, rich = rich, L19 = L19, err = rows) }
saveRDS(out, file.path(SU, "score.rds"))
