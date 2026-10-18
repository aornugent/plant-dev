# own_model.R: the own (interpolation) part of any schedule's ln J error, from a uniform
# reference's fates. F(b) = disturbance density x nrr, nrr from a spline of ln nrr through
# the reference's nodes inside each panel (opening edge to opening edge, so the corners sit
# at opening edges); e(b) = the pilot's creation rate rescaled to the reference's exact
# establishment per reference interval. own(S) = ln(sum W_i F(b_i) / int e F), W the hats'
# weights on S. Evaluated for layout D (rho0, 2 rho0, 4 rho0), its alternate drop, and the
# guard (the reference's every-other subset against the exact nested own part).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
suppressMessages(library(plant, lib.loc = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/libS"))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
REFS <- list(`flat-al1125` = file.path(SC, "heldout/runs/ref_flat-al1125_u857.rds"), `episodic-lma` = file.path(SC, "refine/runs/ref_episodic-lma_u857.rds"),
  `dry-lma125` = file.path(SC, "refine/runs/ref_dry-lma125_u857.rds"), `dry-p50` = file.path(AR, "ref_dry-p50_u429.rds"),
  `wet-hmat125` = file.path(SC, "heldout/runs/ref_wet-hmat125_u429.rds"))
u <- 0.025; DT <- 0.25 / 365
model_of <- function(cs) {
  r <- readRDS(REFS[[cs]])$stand; n <- r$nodes; b <- n$birth; m <- length(b); px <- pilot_run(cs); ea <- edges_all(cs, px)
  g <- seq(0, H, by = DT); gm <- head(g, -1) + DT / 2
  cr <- px$creation; rate <- cr$rate[pmax(1, findInterval(gm, cr$start))]
  Eref <- n$state["interval_establishment", ]; ji <- findInterval(gm, b); s <- tapply(rate * DT, factor(ji, levels = 1:m), sum); s[is.na(s)] <- 0
  fac <- ifelse(s > 0, Eref / s, 0); e <- rate * fac[ji]
  # intervals with exact establishment but no pilot rate: spread it evenly
  miss <- which(s == 0 & Eref > 1e-12); for (j in miss) { k <- ji == j; e[k] <- Eref[j] / (sum(k) * DT) }
  br <- sort(unique(c(0, ea$b[ea$opening], H))); y <- log(pmax(n$nrr, 1e-300)); lf <- numeric(length(gm)); pid <- findInterval(gm, br)
  for (k in seq_len(length(br) - 1)) { z <- pid == k; nk <- which(b >= br[k] & b < br[k + 1])
    if (length(nk) >= 3) lf[z] <- splinefun(b[nk], y[nk], method = "natural")(gm[z])
    else if (length(nk) == 2) lf[z] <- approx(b[nk], y[nk], gm[z], rule = 2)$y
    else { nb <- order(abs(b - (br[k] + br[k + 1]) / 2))[1:2]; lf[z] <- approxfun(b[nb], y[nb], rule = 2)(gm[z]) } }
  Fg <- dens(gm) * exp(lf)
  Fat <- function(x) { i <- pmin(pmax(round((x - DT / 2) / DT) + 1, 1), length(gm)); Fg[i] }
  list(cs = cs, b = b, w = n$establishment[1:m], nrr = n$nrr, gm = gm, e = e, Fg = Fg, Fat = Fat, T = sum(e * Fg) * DT, br = br, J = r$J) }
# hat weights of S against the density e on the fine grid
weights_of <- function(M, S) { j <- findInterval(M$gm, S); j[j < 1] <- 1; nx <- pmin(j + 1, length(S))
  t <- ifelse(j >= length(S), 0, (M$gm - S[j]) / (S[nx] - S[j])); f <- factor(j, levels = seq_along(S))
  as.numeric(tapply(M$e * (1 - t) * DT, f, sum, default = 0) + tapply(M$e * t * DT, factor(nx, levels = seq_along(S)), sum, default = 0)) }
# S closed by the horizon as a node (plant's boundary node), F there from the model
Q_of <- function(M, S) { S <- sort(unique(c(S, H))); sum(weights_of(M, S) * M$Fat(S)) }
own <- function(M, S) log(Q_of(M, S) / M$T) / u
# the same, split by panel of D (contribution of each interval's error, in eps of ln J)
own_by_interval <- function(M, S) { S <- sort(unique(c(S, H))); j <- findInterval(M$gm, S); j[j < 1] <- 1; nx <- pmin(j + 1, length(S))
  t <- ifelse(j >= length(S), 0, (M$gm - S[j]) / (S[nx] - S[j])); Fs <- M$Fat(S)
  lin <- Fs[j] * (1 - t) + Fs[nx] * t; d <- tapply(M$e * (lin - M$Fg) * DT, factor(j, levels = seq_along(S)), sum, default = 0) / M$T / u
  data.frame(lo = S, err = as.numeric(d)) }
