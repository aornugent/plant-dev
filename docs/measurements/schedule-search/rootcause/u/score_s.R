# score_s.R CASE...: S, U's moves split by the hybrid runs. d1 = x - c = (x - xh) + (xh - c),
# d2 = c - f = (c - fh) + (fh - f); the second term of each is the part made by the stretches
# that refine on both steps (R), the first by S*. Orders against the a09 proxy's law
# (P_a^q - P_b^q)/(P_b^q - P_c^q) = ratio, p = 2q, for all, R, and R plus the narrow S*
# (the wide-only hybrids xw, fw); S*'s share of the deficit (p_R - p)/(2 - p).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
qord <- function(Px, Pc, Pf, rho) { if (!is.finite(rho) || rho <= 0) return(NA); f <- function(q) log((Px^q - Pc^q) / (Pc^q - Pf^q)) - log(rho)
  lo <- 0.05; hi <- 4; if (f(lo) * f(hi) > 0) return(if (f(hi) < 0) 2 * hi else 2 * lo); 2 * uniroot(f, c(lo, hi))$root }
OUT <- list()
for (cs in commandArgs(TRUE)) { RR5 <- lapply(c(x = "U16", c = "U10", f = "U06", xh = "Uxh", fh = "Ufh", xw = "Uxw", fw = "Ufw"), function(k) h5_run(sprintf("h5_%s_%s", k, cs)))
  if (any(vapply(RR5[c("x", "c", "f", "xh", "fh")], is.null, TRUE))) { cat(cs, ": runs missing\n"); next }
  ref <- ref5(cs); p <- pilot_of(cs); k <- Reduce(intersect, lapply(RR5[!vapply(RR5, is.null, TRUE)], function(z) names(quantities(z))), names(ref)); e <- eps_vec(k)
  E <- lapply(RR5, function(z) if (is.null(z)) NULL else (quantities(z)[k] - ref[k]) / e); P <- lapply(RR5, function(z) if (is.null(z)) NA else alg$proxy_err(p, sort(z$node_times)))
  d1 <- E$x - E$c; d2 <- E$c - E$f; d1R <- E$xh - E$c; d2R <- E$c - E$fh; d1S <- E$x - E$xh; d2S <- E$fh - E$f
  big <- function(a, b) abs(a) > 0.1 & abs(b) > 0.05
  pq <- function(a, b, Pa, Pb, Pc) { j <- big(a, b); if (!any(j)) return(c(med = NA, n = 0)); qo <- sapply(which(j), function(i) qord(Pa, Pb, Pc, a[i] / b[i])); c(med = median(qo, na.rm = TRUE), n = sum(j)) }
  p_all <- qord(P$x, P$c, P$f, proj(d1, d2)); p_R <- qord(P$xh, P$c, P$fh, proj(d1R, d2R))
  o <- data.frame(case = cs, nodes = paste(sapply(RR5[c("x", "c", "f", "xh", "fh")], function(z) length(z$node_times)), collapse = "/"),
    law_all = (P$x - P$c) / (P$c - P$f), law_R = (P$xh - P$c) / (P$c - P$fh), rho_all = proj(d1, d2), rho_R = proj(d1R, d2R),
    p_all = p_all, p_R = p_R, share = (p_R - p_all) / (2 - p_all), cos_all = cosv(d1, d2), cos_R = cosv(d1R, d2R),
    pq_all = pq(d1, d2, P$x, P$c, P$f)[["med"]], pq_R = pq(d1R, d2R, P$xh, P$c, P$fh)[["med"]],
    rms_d1 = r2(d1), rms_d1S = r2(d1S), rms_d2 = r2(d2), rms_d2S = r2(d2S), M_d1 = onM(d1), M_d1S = onM(d1S), M_d2 = onM(d2), M_d2S = onM(d2S),
    cos_d1S_d1 = cosv(d1S, d1), cos_d2S_d2 = cosv(d2S, d2), lnJ_d1S = d1S[["lnJ"]], lnJ_d1 = d1[["lnJ"]])
  if (!is.null(E$xw) && !is.null(E$fw)) { d1W <- E$xw - E$c; d2W <- E$c - E$fw; pW <- qord(P$xw, P$c, P$fw, proj(d1W, d2W))
    o <- cbind(o, data.frame(law_Rw = (P$xw - P$c) / (P$c - P$fw), rho_Rw = proj(d1W, d2W), p_Rw = pW, cos_Rw = cosv(d1W, d2W), wide_share = (pW - p_all) / (p_R - p_all), M_d1W = onM(E$x - E$xw), M_d2W = onM(E$fw - E$f))) }
  OUT[[cs]] <- o
  cat(sprintf("\n== %s: top S* parts of d1: %s\n   of d2: %s\n   R d1: %s\n   R d2: %s\n", cs, top(d1S, 5), top(d2S, 5), top(d1R, 5), top(d2R, 5))) }
nm <- unique(unlist(lapply(OUT, names))); OUT <- lapply(OUT, function(o) { o[setdiff(nm, names(o))] <- NA; o[nm] }); O <- do.call(rbind, OUT); rownames(O) <- NULL; saveRDS(O, file.path(UOUT, "score_s.rds")); op <- options(width = 250); print(t(O), digits = 3, quote = FALSE)
