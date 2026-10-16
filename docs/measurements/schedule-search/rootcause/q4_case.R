# q4_case.R: per case, the error per unit of the a09 proxy, by region, from single-axis
# lattice moves at 3e-5 (founders: f 32 -> 64 at l 70; spells: l 70 -> 35 at f 32, or f 16
# where f 32 lacks it). Error at the coarse level = 4/3 of the move (square law, q1).
# Which pilot quantity carries the case-to-case variation?
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
v <- function(nm) qn(nm)[Q] / EPS; S_of <- function(nm) sort(RR[[byname(nm)]]$S)
PC <- lapply(setNames(ALL, ALL), pilot_ctx)
band_proxy <- function(cs, S, lo, hi) { p <- PC[[cs]]; n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  a <- head(S, -1); b <- S[-1]; m <- (a + b) / 2; w <- exp(0.6 * lf(m)); w[p$shut(m) > 0.5] <- 0; j <- m >= lo & m < hi; sum((w * (b - a)^3)[j]) }
rows <- list()
for (cs in ALL) { b1 <- PIL[[cs]]$b1; nmF <- sprintf("lat_%s_f%d_l70", cs, c(32, 64))
  eF <- -4 / 3 * (v(nmF[2]) - v(nmF[1])); pF <- band_proxy(cs, S_of(nmF[1]), 0, b1)
  f <- if (sprintf("lat_%s_f32_l35", cs) %in% TAB$name) 32 else 16; nmL <- sprintf("lat_%s_f%d_l%s", cs, f, c("70", "35"))
  eL <- -4 / 3 * (v(nmL[2]) - v(nmL[1])); pL <- band_proxy(cs, S_of(nmL[1]), b1, 40)
  p <- PC[[cs]]; n <- p$nodes; cr <- p$creation; fr <- n$birth < b1
  y <- log(pmax(n$nrr, 1e-300)); yF <- y[fr]; bF <- n$birth[fr]
  et <- PIL[[cs]]$edges; e25 <- et[et < 25 & et > b1]
  open25 <- with(cr, sum(((end - start) * (rate > 0.01))[start >= b1 & start < 25])) / (25 - b1)
  estab <- with(cr, c(F = sum((rate * (end - start))[start < b1]), A = sum((rate * (end - start))[start >= b1 & start < 25])))
  rows[[cs]] <- data.frame(case = cs, eF_rms = sqrt(mean(eF^2)), eF_lnJ = eF["lnJ"], kF = sqrt(mean(eF^2)) / pF, eL_rms = sqrt(mean(eL^2)), eL_lnJ = eL["lnJ"], kL = sqrt(mean(eL^2)) / pL,
    cosF_M = sum(eF * M_unit) / sqrt(sum(eF^2)), cosL_M = sum(eL * M_unit) / sqrt(sum(eL^2)),
    b1 = b1, J = p$J, lnrr0 = yF[1], dropF = yF[1] - tail(yF, 1), curvF = if (length(yF) > 3) max(abs(diff(yF, differences = 2))) / mean(diff(bF))^2 else NA,
    nedge25 = length(e25), open25 = open25, estF = estab["F"] / sum(estab), lnrr_spell = median(y[n$birth > b1 & n$birth < 25]), row.names = NULL) }
D <- do.call(rbind, rows); options(width = 200); print(format(D, digits = 3), row.names = FALSE)
cat(sprintf("\nspread of error per unit proxy across cases: founders kF max/min %.1f (cv %.2f); spells kL max/min %.1f (cv %.2f)\n",
  max(D$kF) / min(D$kF), sd(D$kF) / mean(D$kF), max(D$kL) / min(D$kL), sd(D$kL) / mean(D$kL)))
# one-predictor LOCO fits of log k on each pilot quantity (10 points: read as a screen only)
for (tg in c("kF", "kL")) { cat("\n", tg, ": LOCO factor error of log", tg, "~ pilot quantity (median, max over cases)\n")
  base <- vapply(seq_len(nrow(D)), function(i) abs(log(D[[tg]][i]) - mean(log(D[[tg]][-i]))), 0)
  cat(sprintf("   %-11s median x%.2f max x%.2f\n", "none", exp(median(base)), exp(max(base))))
  for (x in c("b1", "J", "lnrr0", "dropF", "curvF", "nedge25", "open25", "estF", "lnrr_spell")) { if (any(!is.finite(D[[x]]))) next
    r <- vapply(seq_len(nrow(D)), function(i) { m <- lm(log(D[[tg]][-i]) ~ D[[x]][-i]); abs(log(D[[tg]][i]) - sum(coef(m) * c(1, D[[x]][i]))) }, 0)
    cat(sprintf("   %-11s median x%.2f max x%.2f\n", x, exp(median(r)), exp(max(r)))) } }
saveRDS(D, file.path(OUT, "q4_case.rds"))
# The proxy's weight is the pilot's nrr^0.6 in absolute units; a quantity in eps is a
# relative one. Normalise: w = (nrr / J_pilot)^p, and read the spread of k across cases.
cat("\n== normalised proxy w = (nrr / J_pilot)^p: spread of error per unit proxy across the ten cases\n")
for (pw in c(0.6, 0.8, 1, 1.2)) {
  bp <- function(cs, S, lo, hi) { p <- PC[[cs]]; n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)) - log(p$J), rule = 2)
    a <- head(S, -1); b <- S[-1]; m <- (a + b) / 2; w <- exp(pw * lf(m)); w[p$shut(m) > 0.5] <- 0; j <- m >= lo & m < hi; sum((w * (b - a)^3)[j]) }
  k <- t(sapply(ALL, function(cs) { b1 <- PIL[[cs]]$b1; nmF <- sprintf("lat_%s_f%d_l70", cs, c(32, 64)); f <- if (sprintf("lat_%s_f32_l35", cs) %in% TAB$name) 32 else 16
    nmL <- sprintf("lat_%s_f%d_l%s", cs, f, c("70", "35"))
    c(kF = D$eF_rms[D$case == cs] / bp(cs, S_of(nmF[1]), 0, b1), kL = D$eL_rms[D$case == cs] / bp(cs, S_of(nmL[1]), b1, 40)) }))
  lo <- function(x) { r <- vapply(seq_along(x), function(i) abs(log(x[i]) - mean(log(x[-i]))), 0); sprintf("LOCO median x%.2f max x%.2f", exp(median(r)), exp(max(r))) }
  cat(sprintf("  p %.1f | founders: max/min %5.1f, %s | spells: max/min %5.1f, %s\n", pw, max(k[, "kF"]) / min(k[, "kF"]), lo(k[, "kF"]), max(k[, "kL"]) / min(k[, "kL"]), lo(k[, "kL"])))
  if (pw == 1) print(round(k, 3)) }
