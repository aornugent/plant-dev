# q3_predict.R: what predicts the founders' error from the pilot? Measured: the lattice's
# founders' error at f = 32 (q1_lattice.rds; all ten). Proxies at that spacing (b1/32),
# from the pilot (54 uniform nodes): the J-normalised a09 weight (nrr/J)^0.6 h^3 and the
# founders' window rule 0.055 g'^2 f/J h^3. Candidate case factors: the case's elasticity
# scale (rms of its elasticities in eps, from the lattice f64 run), the pilot's ln J, L.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
lat <- readRDS(file.path(FO, "q1_lattice.rds")); rms <- function(x) sqrt(mean(x^2))
rows <- list()
for (cs in ALL) { p <- pilot_ctx(cs); n <- p$nodes; b1 <- p$b1; Jp <- p$J
  lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  S <- seq(0, b1, length.out = 33); lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; h <- hi - lo
  gp <- (lf(hi) - lf(lo)) / h                                    # the pilot's slope, read at this spacing
  pA <- sum((exp(lf(m)) / Jp)^0.6 * h^3)
  pB <- sum(0.055 * gp^2 * exp(lf(m)) / Jp * h^3)
  i <- n$birth < b1; Lp <- -1 / coef(lm(log(n$nrr[i]) ~ n$birth[i]))[2]
  e <- lat[[cs]]$eF32
  el <- qn(sprintf("lat_%s_f64_l70", cs))[Q]; escale <- rms((el / EPS)[names(el) != "lnJ"])
  rows[[cs]] <- data.frame(case = cs, rms = rms(e), worst = max(abs(e)), lnJ = e["lnJ"], pA = pA, pB = pB, lnJp = log(Jp), L = Lp, escale = escale, npil = sum(i)) }
T <- do.call(rbind, rows); rownames(T) <- NULL
T$fA <- T$rms / T$pA; T$fB <- T$rms / T$pB; T$fBl <- abs(T$lnJ) / T$pB
T$fBs <- T$rms / (T$pB * T$escale)
print(T, digits = 3)
spread <- function(x) sprintf("max/min %.1f, episodic-lma / median of the others %.2f", max(x) / min(x), x[T$case == "episodic-lma"] / median(x[T$case != "episodic-lma"]))
cat("rms / a09 J-normalised proxy:            ", spread(T$fA), "\n")
cat("rms / founders' rule (0.055 g'^2 f/J):   ", spread(T$fB), "\n")
cat("|lnJ| / founders' rule:                  ", spread(T$fBl), "\n")
cat("rms / (founders' rule x elasticity scale):", spread(T$fBs), "\n")
cat(sprintf("Spearman of rms/rule with: elasticity scale %.2f, ln J_pilot %.2f, L %.2f\n", cor(T$fB, T$escale, method = "s"), cor(T$fB, T$lnJp, method = "s"), cor(T$fB, T$L, method = "s")))
saveRDS(T, file.path(FO, "q3_predict.rds"))
