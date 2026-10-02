# A partitioned step for the long-drought stand of harness/ark_prototype.R.
# The members take Cash-Karp steps under their own error control (the soil and
# the flux accumulators out of their norm). Inside each member step [t, t + H]
# the soil chain (five layers and five accumulators) is sub-stepped on its own by
# Cash-Karp at SOIL_TOL, landing on the member stages' times, and the member
# stages read the soil there. The soil's uptake per layer comes from COUPLING:
#   held    each node's collar suction, root network, leaf area and density held
#           at t; each layer's draw re-derived from the collar (uptake_at);
#   exact   every member's leaf re-solved at each soil stage, the members' state
#           held at t (one full rate evaluation per soil stage);
#   stage   held, the hold refreshed at each member stage as the soil reaches it;
#   defect  held, then the soil's end corrected by the stages' quadrature of the
#           uptake each member stage evaluated against the held uptake there.
#
#   PLANT_LIB=$DEV/split/lib NODES=108 TOL=3e-5 ATOL=1e-4 SOIL_TOL=3e-5 COUPLING=held \
#     [SUB_ACC=1] [OUT=run.rds] [STEP_LOG=1] [PROGRAM=run.rds [THETA=lma THETA_REL=1e-5]] \
#     Rscript split_stepper.R
#
# HMAX caps the member step at that many days. SUB_ACC=0 leaves the accumulators
# out of the soil's norm. STEP_LOG keeps, per
# accepted member step, the soil's sub-steps and the uptake defect at each stage.
# PROGRAM replays an OUT file's accepted member steps with no member control (the
# soil sub-cycle stays adaptive), for frozen-step differences in THETA.
# Soil-chain checks: CHECK=1 compares the soil rates and the held uptake with the
# patch's own at every member evaluation of the first leg's steps, and stops.
Sys.setenv(METHOD = "ck")
source("/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/harness/ark_prototype.R")

SOIL_TOL <- as.numeric(Sys.getenv("SOIL_TOL", Sys.getenv("TOL", "1e-3")))
SOIL_ATOL <- as.numeric(Sys.getenv("ATOL", "1")) * SOIL_TOL
COUPLING <- match.arg(Sys.getenv("COUPLING", "held"), c("held", "exact", "stage", "defect"))
SUB_ACC <- Sys.getenv("SUB_ACC", "1") == "1"
STEP_LOG <- nzchar(Sys.getenv("STEP_LOG"))
CHECK <- nzchar(Sys.getenv("CHECK"))
LEGS <- as.integer(Sys.getenv("LEGS", "0"))

# TF24_Environment::compute_rates, with the environment's own parameters.
e_K_sat <- env$K_sat; e_theta_s <- env$soil_moist_sat; e_q <- 2 * env$n_psi + 3
e_a_inf <- env$a_infil; e_b_inf <- env$b_infil; e_dz <- env$depth / 5
e_theta_res <- 1e-2
soil_rates <- function(s, t, a) {
  th <- s[1:5]
  rain <- max(0, env$extrinsic_drivers_evaluate("rainfall", t))
  excess <- 1 - e_a_inf * (th[1] / e_theta_s)^e_b_inf
  infil <- rain * max(0, excess)
  K <- e_K_sat * (pmin(pmax(th, 0), e_theta_s) / e_theta_s)^e_q
  r <- (c(infil, K[1:4]) - K - a) / e_dz
  r[th <= e_theta_res & !(r > 0)] <- 0
  tot <- 0
  for (i in 1:5) tot <- tot + a[i]
  c(r, rain, infil, K[5], tot, 0)
}

cnt <- new.env()
for (x in c("uptake_calls", "uptake_at", "soil_rates", "sub_accepted", "sub_rejected",
            "sub_thrown", "sub_members", "holds", "macro_attempts")) assign(x, 0, envir = cnt)

members_of <- function(y) seq_len(length(y) - 10)
soil_of <- function(y) length(y) - 9:0
n_nodes <- function(y) (length(y) - 10) %/% 9

# The held uptake at layer moisture th; NULL where uptake_at refuses.
held_uptake <- function(held, nodes, collar = numeric(0)) {
  function(th, tt) {
    cnt$uptake_calls <- cnt$uptake_calls + 1
    cnt$uptake_at <- cnt$uptake_at + nodes + 1
    tryCatch(plant:::split_uptake_tf24(held, th, collar, FALSE), error = function(e) NULL)
  }
}
# Every member's leaf re-solved at layer moisture th, the members at y0, time t0.
exact_uptake <- function(y0, t0) {
  function(th, tt) {
    y <- y0
    y[soil(y)] <- th
    cnt$sub_members <- cnt$sub_members + n_nodes(y)
    ok <- tryCatch({ patch$derivs(y, t0); TRUE }, `odelia::util::DomainError` = function(e) FALSE)
    if (!ok) return(NULL)
    tail(patch$ode_aux, 5)
  }
}

# The soil's error ratio, OdeControl's level at SOIL_TOL.
soil_ratio <- function(h, s, serr, ds) {
  level <- SOIL_TOL * (ct$ode_a_y * abs(s) + ct$ode_a_dydt * abs(h * ds)) + SOIL_ATOL
  r <- abs(serr) / abs(level)
  if (!SUB_ACC) r <- r[1:5]
  if (any(!is.finite(r))) return(Inf)
  max(r, .Machine$double.xmin)
}

# One Cash-Karp attempt on the soil from (t, s) with rates k1.
soil_attempt <- function(t, s, k1, h, up) {
  k <- list(k1)
  for (i in 2:6) {
    Y <- combine(s, tb$A[i, ], k, h)
    a <- up(Y[1:5], t + tb$c[i] * h)
    if (is.null(a)) return(NULL)
    k[[i]] <- soil_rates(Y, t + tb$c[i] * h, a)
    cnt$soil_rates <- cnt$soil_rates + 1
  }
  s1 <- combine(s, tb$b, k, h)
  a1 <- up(s1[1:5], t + h)
  if (is.null(a1)) return(NULL)
  cnt$soil_rates <- cnt$soil_rates + 1
  list(s = s1, serr = combine(0, tb$b - tb$d, k, h), rates = soil_rates(s1, t + h, a1))
}

# The soil from (t, s) through each of `targets` in turn under uptake `up`, under
# the SCM controller's rules from proposal h: its state at each target, its
# rates and proposal at the last, and the accepted sub-steps (NA where one was
# clipped to its target). With `plan`, those sub-steps are taken as given. NULL
# where a sub-step cannot be taken.
sub <- new.env()
soil_cycle <- function(t, s, k1, targets, up, h, plan = NULL) {
  at <- vector("list", length(targets))
  n_acc <- 0; n_rej <- 0
  taken <- numeric(0)
  j <- 1
  if (!is.null(plan)) {
    for (step_h in plan) {
      final <- is.na(step_h)
      hh <- if (final) targets[j] - t else step_h
      a <- soil_attempt(t, s, k1, hh, up)
      if (is.null(a)) return(NULL)
      t <- if (final) targets[j] else t + hh
      s <- a$s
      k1 <- a$rates
      while (j <= length(targets) && t >= targets[j]) { at[[j]] <- s; j <- j + 1 }
    }
    cnt$sub_accepted <- cnt$sub_accepted + length(plan)
    return(list(at = at, rates = k1, h = h, accepted = length(plan), rejected = 0, plan = plan))
  }
  while (j <= length(targets)) {
    target <- targets[j]
    remaining <- target - t
    final <- h > remaining
    hh <- if (final) remaining else h
    a <- soil_attempt(t, s, k1, hh, up)
    if (is.null(a)) {
      cnt$sub_thrown <- cnt$sub_thrown + 1
      n_rej <- n_rej + 1
      hn <- max(hh * 0.2, ct$ode_step_size_min)
      if (!(hn < hh)) return(NULL)
      h <- hn
      next
    }
    r <- soil_ratio(hh, a$s, a$serr, a$rates)
    if (r > 1.1) {
      hn <- max(hh * max(0.2, 0.9 / r^(1 / 5)), ct$ode_step_size_min)
      if (hn < hh) {
        n_rej <- n_rej + 1
        h <- hn
        next
      }
    }
    n_acc <- n_acc + 1
    taken <- c(taken, if (final) NA else hh)
    t <- if (final) target else t + hh
    s <- a$s
    k1 <- a$rates
    if (!final && r < 0.5) h <- min(hh * min(5, max(1, 0.9 / r^(1 / 6))), ct$ode_step_size_max)
    else if (!final) h <- hh
    while (j <= length(targets) && t >= targets[j]) { at[[j]] <- s; j <- j + 1 }
  }
  cnt$sub_accepted <- cnt$sub_accepted + n_acc
  cnt$sub_rejected <- cnt$sub_rejected + n_rej
  list(at = at, rates = k1, h = h, accepted = n_acc, rejected = n_rej, plan = taken)
}

# The stage order in time: c = 0.2, 0.3, 0.6, 0.875, 1 are stages 2, 3, 4, 6, 5.
STAGE_BY_TIME <- order(tb$c[2:6]) + 1

# One partitioned attempt from (t, y) with member rates k1 and the plants held at
# t in `held`: the state it ends at, the members' error estimate, the rates there.
p_attempt <- function(t, y, k1, h, held, plan = NULL) {
  cnt$macro_attempts <- cnt$macro_attempts + 1
  plans <- list()
  m <- members_of(y); s_idx <- soil_of(y); nn <- n_nodes(y)
  stage_t <- t + tb$c * h
  up0 <- switch(COUPLING,
                exact = exact_uptake(y, t),
                held_uptake(held, nn))
  a_t <- up0(y[soil(y)], t)
  if (is.null(a_t)) return(NULL)
  ks <- soil_rates(y[s_idx], t, a_t)
  soil_at <- vector("list", 6)
  soil_at[[1]] <- y[s_idx]
  k <- list(k1)
  defect <- matrix(0, 6, 5)
  true_up <- matrix(0, 6, 5)
  true_up[1, ] <- a_t
  stage_rates <- function(i, Ys) {
    Y <- combine(y, tb$A[i, ], k, h)
    Y[s_idx] <- Ys
    ki <- rates(Y, stage_t[i])
    if (is.null(ki)) return(NULL)
    list(Y = Y, k = ki, a = tail(patch$ode_aux, 5))
  }
  hsub <- sub$h
  if (COUPLING == "stage") {
    # The soil marched stage by stage, its hold refreshed from each member stage
    # it reaches: [0, .2] from t, [.2, .3] from stage 2, [.3, .6] from stage 3,
    # [.6, 1] (through .875) from stage 4.
    hold <- held
    s <- y[s_idx]; tt <- t; kss <- ks
    for (i in 2:4) {
      cyc <- soil_cycle(tt, s, kss, stage_t[i], held_uptake(hold, nn), hsub, plan[[i - 1]])
      if (is.null(cyc)) return(NULL)
      plans[[i - 1]] <- cyc$plan
      s <- cyc$at[[1]]; tt <- stage_t[i]; hsub <- cyc$h
      soil_at[[i]] <- s
      e <- stage_rates(i, s)
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      defect[i, ] <- e$a - held_uptake(hold, nn)(s[1:5], stage_t[i])
      hold <- plant:::split_hold_tf24(patch)
      cnt$holds <- cnt$holds + 1
      # the soil's rates at the refreshed hold
      kss <- soil_rates(s, tt, held_uptake(hold, nn)(s[1:5], tt))
    }
    cyc <- soil_cycle(tt, s, kss, stage_t[c(6, 5)], held_uptake(hold, nn), hsub, plan[[4]])
    if (is.null(cyc)) return(NULL)
    plans[[4]] <- cyc$plan
    soil_at[[6]] <- cyc$at[[1]]; soil_at[[5]] <- cyc$at[[2]]
    for (i in 5:6) {
      e <- stage_rates(i, soil_at[[i]])
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      defect[i, ] <- e$a - held_uptake(hold, nn)(soil_at[[i]][1:5], stage_t[i])
    }
  } else {
    cyc <- soil_cycle(t, y[s_idx], ks, stage_t[STAGE_BY_TIME], up0, hsub, plan[[1]])
    if (is.null(cyc)) return(NULL)
    plans[[1]] <- cyc$plan
    for (j in seq_along(STAGE_BY_TIME)) soil_at[[STAGE_BY_TIME[j]]] <- cyc$at[[j]]
    # For exact, the defect is the members' own move over the step: the stage's
    # uptake less the uptake with the members held at t, at the stage's moisture.
    held_up <- if (COUPLING == "exact") up0 else held_uptake(held, nn)
    for (i in 2:6) {
      e <- stage_rates(i, soil_at[[i]])
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      a_h <- held_up(soil_at[[i]][1:5], stage_t[i])
      if (is.null(a_h)) return(NULL)
      defect[i, ] <- e$a - a_h
    }
  }
  y1 <- combine(y, tb$b, k, h)
  y1[s_idx] <- soil_at[[5]]
  if (COUPLING == "defect") {
    # The stages' quadrature of the uptake they evaluated against the held one.
    dq <- h * colSums(tb$b * defect)
    y1[soil(y1)] <- y1[soil(y1)] - dq / e_dz
    y1[length(y1) - 1] <- y1[length(y1) - 1] + sum(dq)
  }
  at_end <- rates(y1, t + h)
  if (is.null(at_end)) return(NULL)
  a_end <- tail(patch$ode_aux, 5)
  hold_end <- plant:::split_hold_tf24(patch)
  cnt$holds <- cnt$holds + 1
  yerr <- combine(0, tb$b - tb$d, k, h)
  yerr[s_idx] <- 0
  list(y = y1, yerr = yerr, rates = at_end, P = production(y1), K = klass(y1),
       held = hold_end, h_sub = cyc$h, sub_acc = cyc$accepted, sub_rej = cyc$rejected,
       defect = defect, true_up = true_up, a_end = a_end, plans = plans)
}

slog <- new.env()
slog$rows <- list()
HMAX <- as.numeric(Sys.getenv("HMAX", "Inf")) / 365
p_step <- function(target) {
  t0 <- sv$t
  remaining <- target - t0
  h <- min(sv$h_last, HMAX)
  repeat {
    final <- h > remaining
    if (final) h <- remaining
    a <- p_attempt(t0, sv$y, sv$dydt, h, sv$held)
    if (is.null(a)) {
      hn <- reject(h)
      n$rejected_thrown <- n$rejected_thrown + 1
    } else {
      hn <- adjust(h, a$y, a$yerr, a$rates)
      if (!patch$ode_state_valid(a$y)) {
        hn <- reject(h)
        n$rejected_refused <- n$rejected_refused + 1
      } else if (ctl$shrank) {
        n$rejected_inaccurate <- n$rejected_inaccurate + 1
      } else if (!(ctl$ratio <= 1.1)) {
        n$accepted_at_minimum <- n$accepted_at_minimum + 1
      } else {
        n$accepted <- n$accepted + 1
      }
    }
    if (ctl$shrank) {
      if (hn < h && t0 + hn > t0) {
        h <- hn
        next
      }
      stop(sprintf("Cannot achieve the desired accuracy at t = %.17g", t0))
    }
    sv$t <- if (final) target else t0 + h
    if (!final) sv$h_last <- hn
    sub$h <- a$h_sub
    steps$k <- steps$k + 1L
    if (steps$k > nrow(steps$rows)) steps$rows <- rbind(steps$rows, steps$rows * NA)
    steps$rows[steps$k, ] <- c(sv$t, h, ctl$ratio, ctl$index, (length(a$y) - 10) %/% 9,
                               h * lambda_soil(sv$y, t0) / BETA, a$y[soil(a$y)], 0)
    if (!is.null(steps$states)) steps$states[[steps$k]] <- a$y
    steps$plans[[steps$k]] <- a$plans
    if (STEP_LOG) {
      slog$rows[[length(slog$rows) + 1]] <- list(t0 = t0, h = h, sub_acc = a$sub_acc, sub_rej = a$sub_rej,
                                                defect = a$defect, true_up = a$true_up, a_end = a$a_end)
    }
    sv$y <- a$y
    sv$dydt <- a$rates
    sv$P <- a$P
    sv$K <- a$K
    sv$held <- a$held
    return(invisible())
  }
}

# The soil-chain check: at each of a few states the patch evaluates, the soil
# rates from the patch's own uptake and from the held uptake at its own collars.
check_chain <- function(y, t) {
  r <- rates(y, t)
  a_patch <- tail(patch$ode_aux, 5)
  held <- plant:::split_hold_tf24(patch)
  a_held <- plant:::split_uptake_tf24(held, y[soil(y)], numeric(0), FALSE)
  s_mine <- soil_rates(y[soil_of(y)], t, a_patch)
  c(uptake = max(abs(a_held - a_patch)), uptake_rel = max(abs(a_held - a_patch) / pmax(abs(a_patch), 1e-300)),
    soil = max(abs(s_mine - r[soil_of(y)])), identical_up = identical(a_held, a_patch),
    identical_soil = identical(s_mine, r[soil_of(y)]))
}

if (sys.nframe() == 0L) {
  t_start <- proc.time()[["elapsed"]]
  program_run <- if (nzchar(Sys.getenv("PROGRAM"))) readRDS(Sys.getenv("PROGRAM")) else NULL
  program <- program_run$st
  steps$plans <- list()
  sv$t <- 0
  sv$h_last <- ct$ode_step_size_initial
  sub$h <- ct$ode_step_size_initial
  sv$zone_until <- -Inf
  sv$Pdot <- numeric()
  checks <- list()
  for (k in seq_along(times)) {
    patch$introduce_new_node(1L, times[k])
    sv$y <- patch$ode_state
    sv$dydt <- rates(sv$y, sv$t)
    if (is.null(sv$dydt)) stop("an entry's rates raised DomainError")
    sv$held <- plant:::split_hold_tf24(patch)
    cnt$holds <- cnt$holds + 1
    sv$P <- production(sv$y)
    sv$K <- klass(sv$y)
    t_end <- if (k < length(times)) times[k + 1] else LIFETIME
    if (CHECK) {
      # the monolithic steps of this leg, checking the chain at each start
      for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
        while (sv$t < target) {
          checks[[length(checks) + 1]] <- c(t = sv$t, check_chain(sv$y, sv$t))
          sv$dydt <- rates(sv$y, sv$t)
          step(target)
        }
      }
      if (k >= as.integer(Sys.getenv("CHECK_LEGS", "3"))) {
        ck <- do.call(rbind, checks)
        print(summary(ck))
        cat(sprintf("checked %d states: uptake identical at %d, soil rates identical at %d; max |du| %.3g (rel %.3g), max |dsoil| %.3g\n",
                    nrow(ck), sum(ck[, "identical_up"]), sum(ck[, "identical_soil"]),
                    max(ck[, "uptake"]), max(ck[, "uptake_rel"]), max(ck[, "soil"])))
        quit(save = "no")
      }
      next
    }
    if (!is.null(program)) {
      for (i in which(program$time > sv$t & program$time <= t_end)) {
        h <- program$h[i]
        a <- p_attempt(sv$t, sv$y, sv$dydt, h, sv$held, program_run$plans[[i]])
        if (is.null(a)) stop(sprintf("a pinned partitioned step raised at t = %.17g", sv$t))
        sub$h <- a$h_sub
        sv$t <- program$time[i]
        sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K; sv$held <- a$held
        steps$k <- steps$k + 1L
      }
      next
    }
    for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
      while (sv$t < target) p_step(target)
    }
    if (k == LEGS) break
  }
  secs <- proc.time()[["elapsed"]] - t_start

  sp <- patch$species[[1]]
  w <- sp$establishment_weights
  f <- vapply(sp$nodes, function(x) x$fecundity, 0)
  pd <- sp$patch_densities
  br <- vapply(sp$node_times, function(x) sp$extrinsic_drivers$evaluate("birth_rate", x), 0)
  S_D <- p$strategies[[1]]$pars$S_D
  J <- 0
  for (j in seq_along(f)) J <- J + w[j] * (f[j] * pd[j] * S_D) * br[j]
  J_STAR <- 12.6687135
  att <- vapply(c("accepted", "accepted_at_minimum", "rejected_inaccurate",
                  "rejected_thrown", "rejected_refused"), function(x) n[[x]], 0)
  st <- as.data.frame(steps$rows[seq_len(steps$k), , drop = FALSE])
  cat(sprintf("split %s nodes %d tol %g soil_tol %g: J %.9f (J - J* %.3g relative), %d accepted, %.0f s; %s\n",
              COUPLING, nodes, tol, SOIL_TOL, J, (J - J_STAR) / J_STAR, att[["accepted"]], secs,
              paste(names(att), att, sep = "=", collapse = " ")))
  cat(sprintf("member evaluations %d (rate evaluations %d) + %d in the soil's exact coupling; uptake_at %d in %d uptake sweeps; soil-chain rates %d; soil sub-steps %d accepted, %d rejected, %d thrown; holds %d\n",
              n$members, n$evaluations, cnt$sub_members, cnt$uptake_at, cnt$uptake_calls, cnt$soil_rates,
              cnt$sub_accepted, cnt$sub_rejected, cnt$sub_thrown, cnt$holds))
  acc <- sv$y[length(sv$y) - 4:0]
  cat(sprintf("accumulators at the end: rainfall %.9g infiltration %.9g drainage %.9g uptake %.9g runoff %.3g; soil %s\n",
              acc[1], acc[2], acc[3], acc[4], acc[5], paste(sprintf("%.6g", sv$y[soil(sv$y)]), collapse = " ")))
  if (nzchar(Sys.getenv("OUT"))) {
    saveRDS(list(method = paste0("split_", COUPLING), nodes = nodes, tol = tol, soil_tol = SOIL_TOL, J = J,
                 attempts = att, counts = c(as.list(n), as.list(cnt)), secs = secs, st = st,
                 end_state = sv$y, steplog = if (STEP_LOG) slog$rows else NULL, plans = steps$plans,
                 by_node = data.frame(time = sp$node_times, weight = w[-length(w)],
                                      fecundity = f, patch_density = pd)),
            Sys.getenv("OUT"))
  }
  if (!is.null(steps$states)) saveRDS(steps$states, Sys.getenv("STATES"), compress = FALSE)
}
