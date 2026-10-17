# score_drop1.R CASE TAG SCALE [MODE]: each region's drop1 run (the coarse field at first order, swept),
# or with MODE plain its pinned real coarsening,
# against its base run: the field part of the region's virtual move in every quantity (eps),
# as an error estimate at the committed spacing, field/3/SCALE, against the measured region
# errors (interiors on res from I4; founders on c from fbis, and on res from F2).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
a <- commandArgs(TRUE); cs <- a[1]; tag <- a[2]; sc <- as.numeric(a[3]); md <- if (length(a) > 3) a[4] else "drop1"
dr <- readRDS(file.path(DW, "sched", sprintf("drop_%s_%s.rds", tag, cs))); base <- readRDS(run_file(dr$run))
meas <- readRDS(file.path(DW, sprintf("regions_measured_%s.rds", cs)))$E
Fc <- -4 / 3 * mv_run(readRDS(file.path(FO, "runs", sprintf("fbis_%s.rds", cs))), rd(paste0("val_insk_c_", cs)))
cosv <- function(a, b) { k <- intersect(names(a), names(b)); k <- k[is.finite(a[k]) & is.finite(b[k])]; sum(a[k] * b[k]) / sqrt(sum(a[k]^2) * sum(b[k]^2)) }
est <- list()
for (g in c("I", "F")) { x <- readRDS(file.path(DW, "runs", sprintf("%s_%s_%s_%s.rds", md, tag, g, cs)))
  v <- mv_run(x, base); est[[g]] <- v / 3 / sc
  cat(sprintf("%s %s %s %s: move ln J %+.3f eps (map's first order in score_%s_%s.rds); estimate at committed spacing (/3/%.2f):\n", cs, tag, md, g, v["lnJ"], tag, cs, sc))
  line("  estimate (field only)", est[[g]]) }
line("measured I (res, I4)", meas["I", ]); line("measured F (res, F2)", meas["F", ]); line("measured F (c, fbis)", Fc)
r <- rbind(estI = est$I[KEY], measI = meas["I", KEY], estF = est$F[KEY], measF_c = Fc[KEY], measF_res = meas["F", KEY]); print(round(r, 2))
cat(sprintf("cos over all quantities: est I vs meas I %.2f | est F vs meas F(c) %.2f, F(res) %.2f | est I vs est F %.2f | meas I vs meas F(res) %.2f\n",
  cosv(est$I[-1], meas["I", -1]), cosv(est$F[-1], Fc[-1]), cosv(est$F[-1], meas["F", -1]), cosv(est$I[-1], est$F[-1]), cosv(meas["I", -1], meas["F", -1])))
cat(sprintf("regression slope meas on est (no intercept): I %.2f, F(c) %.2f; rms est I %.3f meas I %.3f; rms est F %.3f meas F(c) %.3f\n",
  sum(est$I[-1] * meas["I", names(est$I)[-1]], na.rm = TRUE) / sum(est$I[-1]^2), sum(est$F[-1] * Fc[names(est$F)[-1]], na.rm = TRUE) / sum(est$F[-1]^2),
  sqrt(mean(est$I[-1]^2)), sqrt(mean(meas["I", -1]^2, na.rm = TRUE)), sqrt(mean(est$F[-1]^2)), sqrt(mean(Fc[-1]^2, na.rm = TRUE))))
saveRDS(list(est = est, Fc = Fc), file.path(DW, sprintf("score_%s_%s_%s.rds", md, tag, cs)))
