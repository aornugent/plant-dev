# The stepper scope's step 4: the long-drought stand (harness/long_drought.R)
# stepped from R through the SCM's schedule under odelia's controller law, with a
# TF24 Patch evaluating every rate. METHOD picks the step:
#   ck    Cash-Karp as a tableau, summed in the solver's order;
#   held  Cash-Karp, each step started at h |lambda_soil| <= HELD_MARGIN beta
#         (default 0.8);
#   ark   ARK4(3)6L[2]SA (harness/ark436.R), the soil's drainage and
#         infiltration solved at each stage by a damped Newton.
#
#   PLANT_LIB=... NODES=108 TOL=1e-3 METHOD=ark [OUT=run.rds] [REF=u108.rds] \
#     [STATES=states.rds] [SWITCH_DAYS=0.05 [SWITCH_AT=0] [SWITCH_BORN=3.6] [SWITCH_UNTIL=25]] \
#     [EVENTS=1 [EVENT_ETA=1e-3] [EVENT_RESTART=0.05] [CLASS_EVENTS=1]] [LOCAL=1] \
#     [TOL_POOL=0.01] [TOL_POOL_ABS=0.01] [POOL_FLOOR=1e-3] [KINK_EST=1] \
#     [CROSS_RESTART=0.1] [CROSS_CAP=1 [CROSS_TAIL=12]] [ONSET_CAP=0.3 [ONSET_SPAN=1.5]] \
#     [TRANSIT=0.5] [KINK_FIX=1] \
#     [PROGRAM=run.rds] [THETA=lma THETA_REL=1e-5] \
#     [ATOL=1e-4] [TOL_SOIL=10] [TOL_ACC=10] [KNOT_SEED=1] [CHAIN_SEED=chain.rds] \
#     [CONTROL=odelia|shrink|pi [PI_BETA=0.04] [PI_ALPHA=0.17] [PI_SAFETY=0.9]] \
#     [ATTEMPT_LOG=attempts.rds] \
#     [LATE_FROM=25 [LATE_FACTOR=100]] [REGIME=long-drought] [TIMES=times.rds] \
#     Rscript harness/ark_prototype.R
#
# REF compares the steps with a recording of harness/v12_steps.R at the same
# nodes and tolerance, which METHOD=ck reproduces bit for bit. STATES keeps the
# state at every accepted step. SWITCH_DAYS refuses a step longer than that
# across which a member's net production crosses SWITCH_AT, and halves it;
# SWITCH_BORN and SWITCH_UNTIL limit that to members born before the one, on
# steps that start before the other.
# EVENTS retakes a step across which a member's net production crosses zero so
# that it ends where the first such member's production is EVENT_ETA past zero,
# and with CLASS_EVENTS (on the probe build) also where a member's leaf changes
# class; the step after it starts at EVENT_RESTART days where that is given,
# else at the proposal the retaken step started with. LOCAL re-integrates each
# member whose net production changes sign within an accepted step on its own,
# on a replay too, where the crossing is found again at the replay's parameters,
# split at the crossing. TOL_POOL scales the storage pools' tolerance weights,
# and TOL_POOL_ABS only their absolute part. PROGRAM replays the accepted steps of
# an OUT file exactly, with no control, and THETA with THETA_REL scales that
# strategy parameter (or the trait lma) by 1 + THETA_REL: together they give J
# on a frozen grid. POOL_FLOOR replaces a pool's absolute
# part by that fraction of 0.05 of its capacity. KINK_EST raises the pool's
# estimate on a step across its switch to the switch's straddling error, and
# CROSS_RESTART caps the proposal after such a step at that many days.
# KINK_EST=all raises the coordinate's, output's and offspring's estimates the
# same way. CROSS_CAP caps a step at that many days from a member's predicted
# downward crossing of zero, read from its P and the slope of P over the last
# step, to CROSS_TAIL days past the last crossing, and refuses a longer step
# across one. ONSET_CAP caps a step at that many days for ONSET_SPAN days after a
# rain onset while any member's P is negative. TRANSIT caps a step so that no
# member's pool moves, at its rate at the step's start, more than that fraction
# of 0.05 of its capacity. KINK_FIX takes from the end of a step across which a
# member's P changed sign the pair's error for that slope jump in its pool,
# coordinate, output and offspring, and evaluates the rates again there. On a
# PROGRAM replay, CROSS_LOG
# saves each crossing of zero by a member's P, CLASS_LOG (on the probe build)
# each change of a member's leaf class, SPLIT takes the rows SPLIT_ROWS names as
# that many steps, and a step that raises reports the stage and the pools it put
# below zero.
#
# ATOL sets the absolute tolerance to that fraction of the relative one, 1e-4
# for the tied tolerance; plant's default is 1. TOL_SOIL scales the soil layers'
# tolerance weights, and TOL_ACC the flux accumulators'. KNOT_SEED caps the
# first attempt after a knot where the rain starts, rises or falls at the size
# accepted after the last knot of that kind. CHAIN_SEED, harness/soil_chain.R's
# OUT on the same record, makes the soil chain alone's first accepted step after
# each knot the first attempt there. CONTROL picks the step-size law after an
# accepted step, as harness/soil_chain.R has them: odelia's (adjust below);
# shrink, the factor 0.9 r^(-1/5) clamped to [0.2, 5]; or pi, shrink with the
# exponent alpha = 1/5 - 0.75 beta and the previous ratio's term r_prev^beta,
# beta = PI_BETA; PI_ALPHA and PI_SAFETY replace alpha and the factor 0.9.
# r_prev is the last accepted step's ratio, floored at 1e-4 and starting at 1. A
# rejection leaves it; a step clipped to its target sets it, though it leaves the
# proposal. ATTEMPT_LOG saves every attempt: its start, size, error ratio
# and binding component, whether it was rejected, thrown or clipped to its
# target, its try within the step, the member evaluations it spent, h |lambda_soil|
# / beta at its start, the proposal it carried, the ratio and growth factor that
# set that proposal, how many members' net production changed sign at a stage or
# its end and whether the binding member's did, that member's pool fill at its
# start and end, and the emptiest pool's fill at its start.
# LATE_FROM scales every tolerance weight by LATE_FACTOR on steps that start at
# or after that time. REGIME runs another record of harness/long_drought.R's
# bank; OUT saves the record's rain and knots. TIMES reads the introductions
# from a file in place of NODES.
# Sourced, it defines the driver and does not run it.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
source(file.path(here, "long_drought.R"))
REGIME <- Sys.getenv("REGIME", SCEN)
stopifnot(REGIME %in% names(RAIN_SPECS))
tab <- new.env()
sys.source(file.path(here, "ark436.R"), envir = tab)

nodes <- as.integer(Sys.getenv("NODES", "108"))
tol <- as.numeric(Sys.getenv("TOL", "1e-3"))
method <- match.arg(Sys.getenv("METHOD", "ck"), c("ck", "held", "ark"))
HELD_MARGIN <- as.numeric(Sys.getenv("HELD_MARGIN", "0.8"))
CONTROL <- match.arg(Sys.getenv("CONTROL", "odelia"), c("odelia", "shrink", "pi"))
PI_BETA <- as.numeric(Sys.getenv("PI_BETA", "0.04"))
PI_ALPHA <- as.numeric(Sys.getenv("PI_ALPHA", NA))
PI_SAFETY <- as.numeric(Sys.getenv("PI_SAFETY", "0.9"))
tb <- if (method == "ark") {
  with(tab, list(A = AE, AI = AI, b = b, d = d, c = cc, ord = 4))
} else {
  with(tab, list(A = ACK, b = bCK, d = dCK, c = cCK, ord = 5))
}

times <- if (nzchar(Sys.getenv("TIMES"))) readRDS(Sys.getenv("TIMES")) else uniform_times(nodes)
nodes <- length(times)
# Each member's pool capacity and relative fill, TF24_Strategy::storage_capacity
# from its height.
pars <- NULL
pool_of <- function(y) 9 * (seq_len((length(y) - 10) %/% 9) - 1) + 6
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
component <- function(i, y) {
  m <- 9 * ((length(y) - 10) %/% 9)
  if (i <= m) NODE[(i - 1) %% 9 + 1] else ENV[i - m]
}
capacity <- function(y) {
  h <- y[pool_of(y) - 5]
  eta_c <- 1 - 2 / (1 + pars$eta) + 1 / (1 + 2 * pars$eta)
  pars$a_st1 * pars$theta * (h / pars$a_l1)^(1 / pars$a_l2) * h * eta_c * pars$rho
}
pulses <- sort(unique(active_knots(REGIME)))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
THETA <- Sys.getenv("THETA")
THETA_REL <- if (nzchar(THETA)) as.numeric(Sys.getenv("THETA_REL")) else 0
if (nzchar(THETA) && THETA != "lma") {
  s <- p$strategy_default; sp_pars <- s$pars
  sp_pars[[THETA]] <- sp_pars[[THETA]] * (1 + THETA_REL)
  s$pars <- sp_pars; p$strategy_default <- s
}
p <- add_strategies(p, trait_matrix(LMA0 * if (THETA == "lma") 1 + THETA_REL else 1, "lma"))
pars <- p$strategies[[1]]$pars
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- as.numeric(Sys.getenv("ATOL", "1")) * tol
ct$node_density_in_birth_date <- TRUE
env <- mkenv(REGIME)
patch <- plant:::Patch("TF24", "TF24_Env")(p, env, ct)

# The soil chain as TF24_Environment::compute_rates has it. Its five layers
# close the state, ahead of the five accumulators.
theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
theta_res <- 0.01
BETA <- 3.7343596   # Cash-Karp's real stability boundary
soil <- function(y) length(y) - 9:5
rain_at <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
# The stiff rates, drainage and infiltration, and their Jacobian in the layers.
stiff_rates <- function(th, rain) {
  out <- K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
  (c(rain * max(0, 1 - (th[1] / theta_s)^b_inf), out[-5]) - out) / dz
}
stiff_jacobian <- function(th, rain) {
  dk <- ifelse(th > 0 & th < theta_s, q * K_sat * (th / theta_s)^q / th, 0) / dz
  J <- diag(-dk)
  J[cbind(2:5, 1:4)] <- dk[1:4]
  if (abs(th[1]) < theta_s) {
    J[1, 1] <- J[1, 1] - rain * b_inf * th[1]^(b_inf - 1) / theta_s^b_inf / dz
  }
  J
}
lambda_soil <- function(y, t) max(-diag(stiff_jacobian(y[soil(y)], rain_at(t))))
# Each member's net production, less SWITCH_AT, at the state the last evaluation
# set: thirteen auxiliaries a member, the third of them.
production <- function(y) {
  patch$ode_aux[13 * (seq_len((length(y) - 10) %/% 9) - 1) + 3] -
    as.numeric(Sys.getenv("SWITCH_AT", "0"))
}
DELTA <- as.numeric(Sys.getenv("SWITCH_DAYS", "Inf")) / 365
SWITCH_BORN <- as.numeric(Sys.getenv("SWITCH_BORN", "Inf"))
SWITCH_UNTIL <- as.numeric(Sys.getenv("SWITCH_UNTIL", "Inf"))
EVENTS <- nzchar(Sys.getenv("EVENTS"))
ETA <- as.numeric(Sys.getenv("EVENT_ETA", "1e-3"))
RESTART <- if (nzchar(Sys.getenv("EVENT_RESTART"))) as.numeric(Sys.getenv("EVENT_RESTART")) / 365 else NA
CLASSES <- nzchar(Sys.getenv("CLASS_EVENTS"))
LOCAL <- nzchar(Sys.getenv("LOCAL"))
TOL_SOIL <- as.numeric(Sys.getenv("TOL_SOIL", "1"))
TOL_ACC <- as.numeric(Sys.getenv("TOL_ACC", "1"))
LATE_FROM <- as.numeric(Sys.getenv("LATE_FROM", NA))
LATE_FACTOR <- as.numeric(Sys.getenv("LATE_FACTOR", "100"))
TOL_POOL <- as.numeric(Sys.getenv("TOL_POOL", "1"))
POOL_FLOOR <- if (nzchar(Sys.getenv("POOL_FLOOR"))) as.numeric(Sys.getenv("POOL_FLOOR")) else NA
KINK_EST <- nzchar(Sys.getenv("KINK_EST"))
KINK_ALL <- Sys.getenv("KINK_EST") == "all"
SPLIT <- as.integer(Sys.getenv("SPLIT", "1"))
CROSS_RESTART <- if (nzchar(Sys.getenv("CROSS_RESTART"))) as.numeric(Sys.getenv("CROSS_RESTART")) / 365 else NA
TOL_POOL_ABS <- as.numeric(Sys.getenv("TOL_POOL_ABS", "1"))
CROSS_CAP <- as.numeric(Sys.getenv("CROSS_CAP", "Inf")) / 365
CROSS_TAIL <- as.numeric(Sys.getenv("CROSS_TAIL", "12")) / 365
ONSET_CAP <- as.numeric(Sys.getenv("ONSET_CAP", "Inf")) / 365
ONSET_SPAN <- as.numeric(Sys.getenv("ONSET_SPAN", "1.5")) / 365
TRANSIT <- as.numeric(Sys.getenv("TRANSIT", "Inf"))
KINK_FIX <- nzchar(Sys.getenv("KINK_FIX"))
# The knots where rain starts after a dry span.
wet <- if (length(pulses) > 1) rain_at((pulses[-1] + pulses[-length(pulses)]) / 2) > 0 else logical()
onsets <- if (length(wet) > 1) pulses[-c(1, length(pulses))][!wet[-length(wet)] & wet[-1]] else numeric()
WINDOW <- 1e-5
klass <- function(y) patch$ode_aux[13 * (seq_len((length(y) - 10) %/% 9) - 1) + 13]

n <- new.env()
for (x in c("evaluations", "members", "switch", "clamp", "floor", "accepted",
            "accepted_at_minimum", "rejected_inaccurate", "rejected_thrown",
            "rejected_refused", "rejected_switch", "rejected_event", "rejected_zone", "located", "located_class",
            "locate_evaluations", "locate_members", "local_members", "local_members_evaluated", "solves", "iterations", "halvings", "failures")) {
  assign(x, 0, envir = n)
}
n$most_iterations <- 0

# One evaluation of the full rates; NULL where the Patch raises DomainError.
# Each counts its members, and the soil clamps its state reaches.
rates <- function(y, t) {
  th <- y[soil(y)]
  n$evaluations <- n$evaluations + 1
  n$members <- n$members + (length(y) - 10) %/% 9
  n$switch <- n$switch + (th[1] > theta_s)
  n$clamp <- n$clamp + any(th < 0 | th > theta_s)
  n$floor <- n$floor + any(th < theta_res)
  tryCatch(patch$derivs(y, t), `odelia::util::DomainError` = function(e) NULL)
}

# y plus h times a tableau row's combination of the rates: the nonzero terms
# in ascending stage, then one h; a one-term row as (a h) k.
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + a[nz] * h * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}

# The block's stage, Y = z + hg F(Y), by Newton from z; a Newton step is halved
# until the residual falls. NULL where it does not converge.
newton <- function(z, hg, rain) {
  n$solves <- n$solves + 1
  Y <- z
  G <- -hg * stiff_rates(Y, rain)
  for (it in 1:30) {
    dY <- solve(diag(5) - hg * stiff_jacobian(Y, rain), -G)
    if (max(abs(dY)) < 1e-12) {
      n$iterations <- n$iterations + it
      n$most_iterations <- max(n$most_iterations, it)
      return(Y + dY)
    }
    a <- 1
    repeat {
      Yn <- Y + a * dY
      Gn <- Yn - z - hg * stiff_rates(Yn, rain)
      if (max(abs(Gn)) < max(abs(G))) break
      a <- a / 2
      n$halvings <- n$halvings + 1
      if (a < 2^-10) break
    }
    if (a < 2^-10) break
    Y <- Yn
    G <- Gn
  }
  n$failures <- n$failures + 1
  NULL
}

# One attempt from (t, y), whose rates are k1: the state it ends at, its error
# estimate and the rates there. NULL where a stage raises or a block solve fails,
# which the step retries smaller.
attempt <- function(t, y, k1, h) {
  k <- list(k1)
  Pst <- list(sv$P)
  blk <- soil(y)
  if (method == "ark") {
    rain <- rain_at(t + tb$c * h)
    kI <- list(stiff_rates(y[blk], rain[1]))
  }
  for (i in 2:6) {
    Y <- combine(y, tb$A[i, ], k, h)
    if (method == "ark") {
      z <- Y[blk]
      for (j in seq_len(i - 1)) z <- z + h * (tb$AI[i, j] - tb$A[i, j]) * kI[[j]]
      Yb <- newton(z, h * tb$AI[i, i], rain[i])
      if (is.null(Yb)) return(NULL)
      Y[blk] <- Yb
    }
    ki <- rates(Y, t + tb$c[i] * h)
    if (is.null(ki)) return(NULL)
    k[[i]] <- ki
    Pst[[i]] <- production(Y)
    if (method == "ark") kI[[i]] <- stiff_rates(Y[blk], rain[i])
  }
  y1 <- combine(y, tb$b, k, h)
  at_end <- rates(y1, t + h)
  if (is.null(at_end)) return(NULL)
  list(y = y1, yerr = combine(0, tb$b - tb$d, k, h), rates = at_end, P = production(y1), K = klass(y1), Pst = Pst)
}

# The size that ends an accepted attempt `a` of size h from t0 just past the
# first switch inside it, or NULL where every switch lies at its end. A switch is
# a member's net production crossing zero, found by regula falsi (Illinois) on
# the step's cubic Hermite interpolant and passed by ETA; with CLASS_EVENTS, also
# a member's leaf changing operating-point class, found by bisection to within
# WINDOW. The probe build puts the class in the thirteenth auxiliary.
crossing_step <- function(t0, h, a) {
  fP <- which(sign(a$P) != sign(sv$P) & abs(a$P) > 3 * ETA)
  fK <- if (CLASSES) which(a$K != sv$K) else integer()
  if (!length(fP) && !length(fK)) return(NULL)
  y0 <- sv$y; f0 <- sv$dydt; y1 <- a$y; f1 <- a$rates
  at <- function(u) {
    y <- (1 + 2 * u) * (1 - u)^2 * y0 + u * (1 - u)^2 * h * f0 + u^2 * (3 - 2 * u) * y1 +
      u^2 * (u - 1) * h * f1
    n$locate_evaluations <- n$locate_evaluations + 1
    n$locate_members <- n$locate_members + (length(y) - 10) %/% 9
    ok <- tryCatch({ patch$derivs(y, t0 + u * h); TRUE }, `odelia::util::DomainError` = function(e) FALSE)
    if (ok) list(P = production(y), K = klass(y)) else NULL
  }
  sizes <- numeric()
  if (length(fP)) {
    j <- fP[which.min(sv$P[fP] / (sv$P[fP] - a$P[fP]))]
    lo <- c(0, sv$P[j]); hi <- c(1, a$P[j]); wlo <- lo[2]; whi <- hi[2]; side <- 0; Pu <- NA
    for (it in 1:30) {
      u <- (lo[1] * whi - hi[1] * wlo) / (whi - wlo)
      e <- at(u)
      if (is.null(e)) break
      Pu <- e$P[j]
      if (sign(Pu) == sign(hi[2])) {
        hi <- c(u, Pu); whi <- Pu
        if (side == -1) wlo <- wlo / 2
        side <- -1
      } else {
        lo <- c(u, Pu); wlo <- Pu
        if (side == 1) whi <- whi / 2
        side <- 1
      }
      if (abs(Pu) < ETA / 2) break
    }
    n$located <- n$located + 1
    slope <- (hi[2] - lo[2]) / ((hi[1] - lo[1]) * h)
    root <- if (is.na(Pu)) lo[1] + lo[2] / (lo[2] - hi[2]) * (hi[1] - lo[1]) else u
    sizes <- c(sizes, root * h + ETA / abs(slope))
  }
  if (length(fK)) {
    lo <- 0; hi <- 1
    while ((hi - lo) * h > WINDOW / 2) {
      u <- (lo + hi) / 2
      e <- at(u)
      if (is.null(e)) break
      if (any(e$K[fK] != sv$K[fK])) hi <- u else lo <- u
    }
    if ((1 - lo) * h > WINDOW) {
      n$located_class <- n$located_class + 1
      sizes <- c(sizes, hi * h)
    }
  }
  hc <- if (length(sizes)) min(sizes) else Inf
  if (is.finite(hc) && hc < h * (1 - 1e-6)) hc else NULL
}

# An accepted attempt `a` of size h from t0 with each member whose net production
# changed sign re-integrated on its own: one Cash-Karp step to the crossing and
# one after it, the rest of the state read from the step's cubic Hermite
# interpolant. NULL where an evaluation raises. Each member-local evaluation
# counts one member, and the rates at the corrected end count its members.
local_fix <- function(t0, h, a) {
  f <- which(sign(a$P) != sign(sv$P))
  if (!length(f)) return(a)
  y0 <- sv$y; f0 <- sv$dydt; y1 <- a$y; f1 <- a$rates
  interp <- function(u) (1 + 2 * u) * (1 - u)^2 * y0 + u * (1 - u)^2 * h * f0 +
    u^2 * (3 - 2 * u) * y1 + u^2 * (u - 1) * h * f1
  full_at <- function(y, u) {
    n$local_members_evaluated <- n$local_members_evaluated + 1
    tryCatch(patch$derivs(y, t0 + u * h), `odelia::util::DomainError` = function(e) NULL)
  }
  out <- y1
  for (j in f) {
    idx <- 9 * (j - 1) + 1:9
    rate_j <- function(yj, u) {
      y <- interp(u); y[idx] <- yj
      r <- full_at(y, u)
      if (is.null(r)) NULL else list(r = r[idx], P = production(y)[j])
    }
    # the crossing, by regula falsi on member j's production along the interpolant
    lo <- c(0, sv$P[j]); hi <- c(1, a$P[j]); wlo <- lo[2]; whi <- hi[2]; side <- 0
    for (it in 1:30) {
      u <- (lo[1] * whi - hi[1] * wlo) / (whi - wlo)
      e <- rate_j(interp(u)[idx], u)
      if (is.null(e)) return(NULL)
      if (sign(e$P) == sign(hi[2])) {
        hi <- c(u, e$P); whi <- e$P; if (side == -1) wlo <- wlo / 2; side <- -1
      } else {
        lo <- c(u, e$P); wlo <- e$P; if (side == 1) whi <- whi / 2; side <- 1
      }
      if (abs(e$P) < ETA / 2) break
    }
    uc <- u
    yj <- y0[idx]; kj <- f0[idx]
    for (seg in list(c(0, uc), c(uc, 1))) {
      hs <- (seg[2] - seg[1]) * h
      if (hs <= 0) next
      if (seg[1] > 0) {
        e <- rate_j(yj, seg[1]); if (is.null(e)) return(NULL); kj <- e$r
      }
      k <- list(kj)
      for (i in 2:6) {
        Y <- combine(yj, tb$A[i, ], k, hs)
        e <- rate_j(Y, seg[1] + tb$c[i] * hs / h); if (is.null(e)) return(NULL)
        k[[i]] <- e$r
      }
      yj <- combine(yj, tb$b, k, hs)
    }
    out[idx] <- yj
    n$local_members <- n$local_members + 1
  }
  r <- tryCatch(patch$derivs(out, t0 + h), `odelia::util::DomainError` = function(e) NULL)
  if (is.null(r)) return(NULL)
  n$local_members_evaluated <- n$local_members_evaluated + length(f)
  a$y <- out; a$rates <- r; a$P <- production(out); a$K <- klass(out)
  a
}

# The error of the propagated solution for a unit slope jump of a quadrature's
# integrand at fraction u of the step, per h^2.
kink_kernel <- function(u) sum(tb$b * pmax(tb$c - u, 0)) - (1 - u)^2 / 2

# The attempt `a` of size h from sv's state, ending at t1, with each member whose
# net production changed sign corrected by -h^2 times each kinked rate's slope
# jump times the kernel at the crossing, and its rates evaluated again there.
kink_fix <- function(h, a, t1) {
  # A member whose P moves less than 100 times P+'s smoothing width across the
  # step has no kink at the step's scale.
  f <- which(sign(a$P) != sign(sv$P) & abs(a$P - sv$P) > 100 * 1e-4)
  if (!length(f)) return(a)
  pool <- pool_of(sv$y)[f]
  # The crossing, between the stages that bracket it, and P's slope there. The
  # end's P stands in for the stage at the step's end.
  cs <- c(tb$c[-5], 1)
  Ps <- cbind(do.call(cbind, a$Pst[-5]), a$P)
  o <- order(cs); cs <- cs[o]; Ps <- Ps[, o, drop = FALSE]
  u <- Pdot <- numeric(length(f))
  for (n in seq_along(f)) {
    p <- Ps[f[n], ]; b <- which(sign(p) != sign(p[1]))[1]
    u[n] <- cs[b - 1] + (cs[b] - cs[b - 1]) * p[b - 1] / (p[b - 1] - p[b])
    Pdot[n] <- abs(p[b] - p[b - 1]) / ((cs[b] - cs[b - 1]) * h)
  }
  K <- vapply(u, kink_kernel, 0)
  r <- (1 - u) * sv$y[pool] / capacity(sv$y)[f] + u * a$y[pool] / capacity(a$y)[f]
  G <- 1 / (1 + exp(-(r - pars$a_st2) / 0.1))
  # The pool's rate has slope (1 - G)(1 - r) in P above zero and r below; the
  # others are P+ times a factor, read at the end where P > 0.
  jump <- list(((1 - G) * (1 - r) - r) * Pdot)
  pos <- sv$P[f] > 0
  for (i in list(pool - 5, pool - 3, pool + 1)) {
    jump[[length(jump) + 1]] <- ifelse(pos, sv$dydt[i] / sv$P[f], a$rates[i] / a$P[f]) * Pdot
  }
  y <- a$y
  for (k in seq_along(jump)) {
    i <- list(pool, pool - 5, pool - 3, pool + 1)[[k]]
    y[i] <- y[i] - h^2 * jump[[k]] * K
  }
  at_end <- rates(y, t1)
  if (is.null(at_end)) return(NULL)
  a$y <- y; a$rates <- at_end; a$P <- production(y); a$K <- klass(y)
  a
}

# With KINK_EST, each member whose net production changed sign across the attempt
# has its pool's estimate raised to the error of the pool's rate switching there:
# h^2 times the jump in the rate's slope times the kernel. Returns the estimate
# and the pool components it changed.
kink_estimate <- function(h, a) {
  f <- which(sign(a$P) != sign(sv$P))
  if (!length(f)) return(list(yerr = a$yerr, pool = integer()))
  pool <- pool_of(sv$y)[f]
  r <- sv$y[pool] / capacity(sv$y)[f]
  G <- 1 / (1 + exp(-(r - pars$a_st2) / 0.1))
  u <- sv$P[f] / (sv$P[f] - a$P[f])
  # The pool's rate has slope (1 - G)(1 - r) in P above zero and r below.
  jump <- abs((1 - G) * (1 - r) - r) * abs(a$P[f] - sv$P[f]) / h
  K <- abs(vapply(u, kink_kernel, 0))
  yerr <- a$yerr
  yerr[pool] <- pmax(abs(yerr[pool]), h^2 * jump * K)
  raised <- pool
  if (KINK_ALL) {
    # The coordinate's, output's and offspring's rates are P+ G times a factor,
    # so their slope in P jumps by rate / P, read at the end where P > 0.
    pos <- sv$P[f] > 0
    P_pos <- ifelse(pos, sv$P[f], a$P[f])
    for (i in list(pool - 5, pool - 3, pool + 1)) {
      rate <- ifelse(pos, sv$dydt[i], a$rates[i])
      yerr[i] <- pmax(abs(yerr[i]), h * abs(rate / P_pos) * abs(a$P[f] - sv$P[f]) * K)
      raised <- c(raised, i)
    }
  }
  list(yerr = yerr, pool = raised)
}

# OdeControl::adjust_step_size and reject_step. `shrank` persists between
# calls, as the solver's flag does where a step at the minimum cannot shrink.
ctl <- new.env()
ctl$shrank <- FALSE
ctl$r_prev <- 1
reject <- function(h) {
  ctl$shrank <- TRUE
  max(h * 0.2, ct$ode_step_size_min)
}
adjust <- function(h, y, yerr, dydt, kink = integer()) {
  level <- ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) +
    ct$ode_tol_abs
  if (TOL_SOIL != 1) level[soil(y)] <- level[soil(y)] * TOL_SOIL
  if (TOL_ACC != 1) level[length(y) - 4:0] <- level[length(y) - 4:0] * TOL_ACC
  if (!is.na(LATE_FROM) && sv$t >= LATE_FROM) level <- level * LATE_FACTOR
  if (TOL_POOL != 1 || TOL_POOL_ABS != 1) {
    pool <- 9 * (seq_len((length(y) - 10) %/% 9) - 1) + 6
    level[pool] <- (level[pool] - ct$ode_tol_abs * (1 - TOL_POOL_ABS)) * TOL_POOL
  }
  if (!is.na(POOL_FLOOR)) {
    pool <- pool_of(y)
    level[pool] <- level[pool] - ct$ode_tol_abs + ct$ode_tol_abs * POOL_FLOOR * 0.05 * capacity(y)
  }
  r <- abs(yerr) / abs(level)
  bad <- which(!is.finite(r))
  if (length(bad)) {
    ctl$index <- bad[1]
    ctl$ratio <- r[bad[1]]
    return(reject(h))
  }
  rmax <- max(r)
  ctl$index <- if (rmax > .Machine$double.xmin) which.max(r) else NA
  ctl$ratio <- if (rmax > .Machine$double.xmin) rmax else 0
  rmax <- max(rmax, .Machine$double.xmin)
  ord <- if (!is.na(ctl$index) && ctl$index %in% kink) 2 else tb$ord
  if (rmax > 1.1) {
    hn <- max(h * max(0.2, 0.9 / rmax^(1 / ord)), ct$ode_step_size_min)
    if (hn < h) {
      ctl$shrank <- TRUE
      h <- hn
    }
  } else if (CONTROL != "odelia") {
    fac <- if (CONTROL == "shrink") 0.9 / rmax^(1 / ord) else
      PI_SAFETY * rmax^-(if (is.na(PI_ALPHA)) 1 / ord - 0.75 * PI_BETA else PI_ALPHA) * ctl$r_prev^PI_BETA
    h <- min(h * min(5, max(0.2, fac)), ct$ode_step_size_max)
    ctl$shrank <- FALSE
  } else if (rmax < 0.5) {
    h <- min(h * min(5, max(1, 0.9 / rmax^(1 / (ord + 1)))), ct$ode_step_size_max)
    ctl$shrank <- FALSE
  } else {
    ctl$shrank <- FALSE
  }
  h
}

# The cap on a step of proposal h from t0, and what set it: 1 for CROSS_CAP, 2
# for ONSET_CAP. Ahead of a predicted crossing the step stops CROSS_CAP short of it.
cap_at <- function(t0, h) {
  cap <- c(Inf, 0)
  if (is.finite(CROSS_CAP)) {
    down <- sv$P > 0 & sv$Pdot < 0
    t_c <- if (any(down)) min(t0 + sv$P[down] / -sv$Pdot[down]) else Inf
    if (t0 < sv$zone_until || t0 + h > t_c - CROSS_CAP) {
      cap <- c(if (t0 < sv$zone_until) CROSS_CAP else max(CROSS_CAP, t_c - CROSS_CAP - t0), 1)
    }
  }
  if (is.finite(TRANSIT)) {
    most <- max(abs(sv$dydt[pool_of(sv$y)]) / capacity(sv$y))
    if (TRANSIT * 0.05 / most < cap[1]) cap <- c(TRANSIT * 0.05 / most, 3)
  }
  if (is.finite(ONSET_CAP) && ONSET_CAP < cap[1] && any(sv$P < 0)) {
    o <- onsets[onsets <= t0]
    if (length(o) && t0 - max(o) < ONSET_SPAN) cap <- c(ONSET_CAP, 2)
  }
  cap
}

# Why a pinned step from (t, y) of size h raised: the first evaluation that
# raises, and each member whose pool that evaluation's state puts below zero.
pinned_raise <- function(t, y, k1, h) {
  k <- list(k1)
  stage <- 7
  for (i in 2:6) {
    Y <- combine(y, tb$A[i, ], k, h)
    ki <- rates(Y, t + tb$c[i] * h)
    if (is.null(ki)) { stage <- i; break }
    k[[i]] <- ki
  }
  if (stage == 7) Y <- combine(y, tb$b, k, h)
  pool <- pool_of(y)
  f <- which(Y[pool] < 0)
  stage_rates <- vapply(f, function(j) paste(sprintf("%.3g", vapply(k, function(x) x[pool[j]], 0)),
                                             collapse = " "), "")
  paste(c(sprintf("a pinned step raised at t = %.17g, h = %.3g days, at evaluation %d of 7", t, 365 * h, stage),
          sprintf("  member %d: r %.3g at the start and %.3g there; P %.3g; h (-dS/dt) / S %.3g; the pool's stage rates %s",
                  f, y[pool[f]] / capacity(y)[f], Y[pool[f]] / capacity(Y)[f], sv$P[f],
                  -h * k1[pool[f]] / y[pool[f]], stage_rates)), collapse = "\n")
}

# SolverInternal::step, towards `target`: a step clipped to reach it lands on it
# and leaves the proposal as it was.
sv <- new.env()
steps <- new.env()
steps$k <- 0L
steps$states <- if (nzchar(Sys.getenv("STATES"))) list() else NULL
steps$rows <- matrix(NA_real_, 60000, 12,
                     dimnames = list(NULL, c("time", "h", "er", "ei", "M", "x_soil",
                                             paste0("soil_", 1:5), "cap")))
attempt_log <- new.env()
attempt_log$k <- 0L
attempt_log$rows <- matrix(NA_real_, 80000, 18, dimnames = list(NULL, c(
  "t0", "h", "ratio", "index", "rejected", "thrown", "final", "try", "members", "x_soil", "proposal",
  "r_set", "f_set", "crossed", "cross_bind", "fill_start", "fill_end", "fill_min")))
# For the attempt `a` from sv's state, whose ratio's component is `index`: how many
# members' net production changed sign at a stage or its end, whether the binding
# member's did, and that member's pool fill at the start and the end.
attempt_signs <- function(a, index, fill0) {
  if (is.null(a)) return(c(NA, NA, NA, NA))
  P <- do.call(cbind, c(a$Pst[-1], list(a$P)))
  changed <- rowSums(sign(P) != sign(sv$P)) > 0
  j <- if (!is.na(index) && index <= 9 * length(sv$P)) (index - 1) %/% 9 + 1 else NA
  if (is.na(j)) return(c(sum(changed), 0, NA, NA))
  c(sum(changed), changed[j], fill0[j], a$y[pool_of(a$y)[j]] / capacity(a$y)[j])
}
KNOT_SEED <- Sys.getenv("KNOT_SEED") == "1"
knot_memory <- new.env()
chain_first <- if (nzchar(Sys.getenv("CHAIN_SEED"))) local({
  r <- readRDS(Sys.getenv("CHAIN_SEED"))$rows
  r[match(pulses, r[, "t0"]), "h"]
})
knot_kind <- function(t) {
  before <- rain_at(t - 0.5 / 365); after <- rain_at(t + 0.5 / 365)
  if (before == 0 && after > 0) "starts" else if (before > 0 && after == 0) "stops" else if (after > before) "rises" else "falls"
}
step <- function(target) {
  t0 <- sv$t
  remaining <- target - t0
  h <- sv$h_last
  kind_here <- if (KNOT_SEED && t0 > 0 && t0 %in% pulses) knot_kind(t0) else NA_character_
  if (!is.na(kind_here) && kind_here != "stops" && !is.null(knot_memory[[kind_here]])) h <- min(h, knot_memory[[kind_here]])
  if (!is.null(chain_first) && t0 > 0 && !is.na(seed <- chain_first[match(t0, pulses)])) h <- seed
  if (method == "held") h <- min(h, HELD_MARGIN * BETA / lambda_soil(sv$y, t0))
  cap <- cap_at(t0, h)
  h <- min(h, cap[1])
  at_crossing <- FALSE
  logged <- nzchar(Sys.getenv("ATTEMPT_LOG"))
  if (logged) {
    tries <- 0L
    x_rate <- lambda_soil(sv$y, t0) / BETA
    fill0 <- sv$y[pool_of(sv$y)] / capacity(sv$y)
  }
  repeat {
    final <- h > remaining
    if (final) h <- remaining
    members0 <- n$members
    a <- attempt(t0, sv$y, sv$dydt, h)
    if (is.null(a)) {
      hn <- reject(h)
      n$rejected_thrown <- n$rejected_thrown + 1
    } else {
      kink <- integer()
      if (KINK_EST) {
        ke <- kink_estimate(h, a)
        a$yerr <- ke$yerr
        kink <- ke$pool
      }
      hn <- adjust(h, a$y, a$yerr, a$rates, kink)
      if (!patch$ode_state_valid(a$y)) {
        hn <- reject(h)
        n$rejected_refused <- n$rejected_refused + 1
      } else if (ctl$shrank) {
        n$rejected_inaccurate <- n$rejected_inaccurate + 1
      } else if (h > CROSS_CAP * (1 + 1e-9) && any(down <- sv$P > 0 & a$P < 0)) {
        hn <- CROSS_CAP
        ctl$shrank <- TRUE
        sv$zone_until <- max(sv$zone_until, t0 + h * min(sv$P[down] / (sv$P[down] - a$P[down])) + CROSS_TAIL)
        n$rejected_zone <- n$rejected_zone + 1
      } else if (h > DELTA && t0 < SWITCH_UNTIL &&
                 any((sign(a$P) != sign(sv$P))[times[seq_along(a$P)] < SWITCH_BORN])) {
        hn <- max(h / 2, DELTA)
        ctl$shrank <- TRUE
        n$rejected_switch <- n$rejected_switch + 1
      } else if (LOCAL && is.null(a <- local_fix(t0, h, a))) {
        hn <- reject(h)
        n$rejected_thrown <- n$rejected_thrown + 1
      } else if (EVENTS && !is.null(hc <- crossing_step(t0, h, a))) {
        h <- hc
        at_crossing <- TRUE
        n$rejected_event <- n$rejected_event + 1
        next
      } else if (!(ctl$ratio <= 1.1)) {
        n$accepted_at_minimum <- n$accepted_at_minimum + 1
      } else {
        n$accepted <- n$accepted + 1
      }
    }
    attempt_log$k <- attempt_log$k + 1L
    if (attempt_log$k > nrow(attempt_log$rows)) attempt_log$rows <- rbind(attempt_log$rows, attempt_log$rows * NA)
    index <- if (is.null(a)) NA else ctl$index
    if (logged) tries <- tries + 1L
    attempt_log$rows[attempt_log$k, ] <- c(t0, h, if (is.null(a)) NA else ctl$ratio, index,
                                            as.numeric(isTRUE(ctl$shrank)), as.numeric(is.null(a)), as.numeric(final),
                                            if (logged) c(tries, n$members - members0, h * x_rate, sv$h_last,
                                                          sv$r_set, sv$f_set, attempt_signs(a, index, fill0),
                                                          min(fill0)) else rep(NA, 11))
    if (ctl$shrank) {
      if (hn < h && t0 + hn > t0) {
        h <- hn
        at_crossing <- FALSE
        next
      }
      stop(sprintf("Cannot achieve the desired accuracy at t = %.17g", t0))
    }
    if (!is.na(kind_here)) knot_memory[[kind_here]] <- h
    sv$t <- if (final) target else t0 + h
    if (!final && !at_crossing) {
      sv$r_set <- ctl$ratio
      sv$f_set <- hn / h
      sv$h_last <- hn
    }
    ctl$r_prev <- max(ctl$ratio, 1e-4)
    if (at_crossing && !is.na(RESTART)) sv$h_last <- RESTART
    if (!is.na(CROSS_RESTART) && any(sign(a$P) != sign(sv$P))) sv$h_last <- min(sv$h_last, CROSS_RESTART)
    if (KINK_FIX && is.null(a <- kink_fix(h, a, sv$t))) stop(sprintf("a corrected step's rates raised at t = %.17g", sv$t))
    steps$k <- steps$k + 1L
    if (steps$k > nrow(steps$rows)) steps$rows <- rbind(steps$rows, steps$rows * NA)
    steps$rows[steps$k, ] <- c(sv$t, h, ctl$ratio, ctl$index, (length(a$y) - 10) %/% 9,
                               h * lambda_soil(sv$y, t0) / BETA, a$y[soil(a$y)], cap[2])
    if (!is.null(steps$states)) steps$states[[steps$k]] <- a$y
    down <- sv$P > 0 & a$P < 0
    if (any(down)) {
      sv$zone_until <- max(sv$zone_until, t0 + h * max(sv$P[down] / (sv$P[down] - a$P[down])) + CROSS_TAIL)
    }
    sv$Pdot <- (a$P - sv$P) / h
    sv$y <- a$y
    sv$dydt <- a$rates
    sv$P <- a$P
    sv$K <- a$K
    return(invisible())
  }
}

if (sys.nframe() == 0L) {
  # SCM::run: each introduction is an entry, and the zero pulses between entries
  # are targets the steps land on.
  t_start <- proc.time()[["elapsed"]]
  program <- if (nzchar(Sys.getenv("PROGRAM"))) readRDS(Sys.getenv("PROGRAM"))$st else NULL
  split_rows <- if (nzchar(Sys.getenv("SPLIT_ROWS"))) unique(readRDS(Sys.getenv("SPLIT_ROWS"))$row) else integer()
  crossings <- list()
  classes <- list()
  LOG_CLASS <- nzchar(Sys.getenv("CLASS_LOG"))
  replay <- list(steps = 0L, ratio_max = 0, over = 0, depth = Inf, over_at = character(), over_x = numeric())
  sv$t <- 0
  sv$h_last <- ct$ode_step_size_initial
  sv$r_set <- sv$f_set <- NA_real_
  sv$zone_until <- -Inf
  sv$Pdot <- numeric()
  for (k in seq_along(times)) {
    patch$introduce_new_node(1L, times[k])
    sv$y <- patch$ode_state
    sv$dydt <- rates(sv$y, sv$t)
    if (is.null(sv$dydt)) stop("an entry's rates raised DomainError")
    sv$P <- production(sv$y)
    sv$Pdot <- c(sv$Pdot, 0)[seq_along(sv$P)]
    sv$K <- klass(sv$y)
    t_end <- if (k < length(times)) times[k + 1] else LIFETIME
    if (!is.null(program)) {
      for (i in which(program$time > sv$t & program$time <= t_end)) {
        n_sub <- if (i %in% split_rows) SPLIT else 1L
        for (k in seq_len(n_sub)) {
          h <- program$h[i] / n_sub
          a <- attempt(sv$t, sv$y, sv$dydt, h)
          if (is.null(a)) stop(pinned_raise(sv$t, sv$y, sv$dydt, h))
          if (LOCAL && is.null(a <- local_fix(sv$t, h, a))) {
            stop(sprintf("a pinned step's member-local re-integration raised at t = %.17g", sv$t))
          }
          f <- which(sign(a$P) != sign(sv$P))
          if (length(f)) crossings[[length(crossings) + 1]] <- data.frame(row = i, member = f,
            t = sv$t + h * sv$P[f] / (sv$P[f] - a$P[f]), down = sv$P[f] > 0, h = h)
          if (KINK_FIX) {
            a <- kink_fix(h, a, if (k == n_sub) program$time[i] else sv$t + h)
            if (is.null(a)) stop(sprintf("a corrected pinned step's rates raised at t = %.17g", sv$t))
          }
          if (LOG_CLASS && length(f <- which(a$K != sv$K))) {
            classes[[length(classes) + 1]] <- data.frame(row = i, member = f, from = sv$K[f], h = h)
          }
          invisible(adjust(h, a$y, a$yerr, a$rates))
          replay$ratio_max <- max(replay$ratio_max, ctl$ratio)
          replay$over <- replay$over + (ctl$ratio > 1.1)
          if (ctl$ratio > 1.1) {
            replay$over_at <- c(replay$over_at, component(ctl$index, a$y))
            replay$over_x <- c(replay$over_x, h * lambda_soil(sv$y, sv$t) / BETA)
          }
          replay$depth <- min(replay$depth, min(a$y[pool_of(a$y)] / capacity(a$y)))
          replay$steps <- replay$steps + 1L
          sv$t <- if (k == n_sub) program$time[i] else sv$t + h
          sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
        }
      }
      next
    }
    for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
      while (sv$t < target) step(target)
    }
  }
  secs <- proc.time()[["elapsed"]] - t_start
  if (!is.null(program)) {
    cat(sprintf("replayed %d steps: error ratio at most %.3g, above 1.1 on %d; deepest pool %.3g of capacity\n",
                replay$steps, replay$ratio_max, replay$over, replay$depth))
    if (replay$over) {
      soil_x <- replay$over_x[grepl("^soil_", replay$over_at)]
      cat("above 1.1, by the component that set the ratio:",
          paste(names(table(replay$over_at)), table(replay$over_at), collapse = ", "),
          sprintf("; h |lambda_soil| / beta on the soil's: median %.3g\n",
                  if (length(soil_x)) median(soil_x) else NA))
    }
    if (nzchar(Sys.getenv("CROSS_LOG"))) saveRDS(do.call(rbind, crossings), Sys.getenv("CROSS_LOG"))
    if (nzchar(Sys.getenv("CLASS_LOG"))) saveRDS(do.call(rbind, classes), Sys.getenv("CLASS_LOG"))
  }

  # Species::offspring_production, on the state the last evaluation set.
  sp <- patch$species[[1]]
  w <- sp$establishment_weights
  f <- vapply(sp$nodes, function(x) x$fecundity, 0)
  pd <- sp$patch_densities
  br <- vapply(sp$node_times, function(x) sp$extrinsic_drivers$evaluate("birth_rate", x), 0)
  S_D <- p$strategies[[1]]$pars$S_D
  stopifnot(length(w) == length(f) + 1, length(pd) == length(f), length(br) == length(f))
  J <- 0
  for (j in seq_along(f)) J <- J + w[j] * (f[j] * pd[j] * S_D) * br[j]

  att <- vapply(c("accepted", "accepted_at_minimum", "rejected_inaccurate",
                  "rejected_thrown", "rejected_refused", "rejected_switch", "rejected_event",
                  "rejected_zone"),
                function(x) n[[x]], 0)
  st <- as.data.frame(steps$rows[seq_len(steps$k), , drop = FALSE])
  if (CONTROL != "odelia") cat("control", CONTROL, "\n")
  cat(sprintf("%s nodes %d tol %g: J %.9f, %d accepted, %.0f s; %s\n", method, nodes, tol,
              J, att[["accepted"]], secs, paste(names(att), att, sep = "=", collapse = " ")))
  cat(sprintf("rate evaluations %d, member evaluations %d; evaluated states past the inflow switch %d, the loss clamp %d, the floor %d\n",
              n$evaluations, n$members, n$switch, n$clamp, n$floor))
  if (LOCAL) {
    cat(sprintf("members re-integrated on their own %d, in %d member evaluations\n",
                n$local_members, n$local_members_evaluated))
  }
  if (EVENTS) {
    cat(sprintf("crossings located %d, class switches located %d, in %d evaluations holding %d members\n",
                n$located, n$located_class, n$locate_evaluations, n$locate_members))
  }
  if (method == "ark") {
    cat(sprintf("block solves %d: %.2f Newton iterations each, at most %d; %d halvings; %d failures\n",
                n$solves, n$iterations / max(1, n$solves - n$failures), n$most_iterations,
                n$halvings, n$failures))
  }
  kind <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  pct <- function(x) sprintf("%.1f%%", 100 * mean(x, na.rm = TRUE))
  cat("binding: soil", pct(grepl("^soil_", kind)), " accumulator", pct(grepl("^accumulator_", kind)),
      " member", pct(kind %in% NODE), " storage", pct(kind == "storage"),
      "; h |lambda_soil| / beta at the start >= 0.8:", pct(st$x_soil >= 0.8),
      " > 1:", pct(st$x_soil > 1), "\n")

  if (nzchar(Sys.getenv("REF"))) {
    ref <- readRDS(Sys.getenv("REF"))
    rs <- ref$st
    ref$attempts[c("rejected_switch", "rejected_event", "rejected_zone")] <- 0
    same <- nrow(rs) == nrow(st) && identical(rs$time, st$time) && identical(rs$h, st$h) &&
      identical(rs$er, st$er) && identical(as.numeric(rs$ei), st$ei)
    cat(sprintf("against the recording: J %s, attempts %s, steps %s\n",
                if (identical(ref$J, J)) "identical" else sprintf("differs by %.3g", J - ref$J),
                if (identical(as.numeric(ref$attempts[names(att)]), as.numeric(att))) "identical" else "differ",
                if (same) "identical" else "differ"))
  }
  if (nzchar(Sys.getenv("ATTEMPT_LOG"))) saveRDS(as.data.frame(attempt_log$rows[seq_len(attempt_log$k), , drop = FALSE]), Sys.getenv("ATTEMPT_LOG"))
  if (!is.null(steps$states)) saveRDS(steps$states, Sys.getenv("STATES"), compress = FALSE)
  if (nzchar(Sys.getenv("OUT"))) {
    saveRDS(list(method = method, control = CONTROL, nodes = nodes, tol = tol, J = J, attempts = att,
                 regime = REGIME, rain = rain_record(REGIME), knots = pulses,
                 counts = as.list(n), secs = secs, st = st,
                 by_node = data.frame(time = sp$node_times, weight = w[-length(w)],
                                      fecundity = f, patch_density = pd)),
            Sys.getenv("OUT"))
  }
}
