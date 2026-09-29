# The stepper scope's step 4: the long-drought stand (harness/long_drought.R)
# stepped from R through the SCM's schedule under odelia's controller law, with a
# TF24 Patch evaluating every rate. METHOD picks the step:
#   ck    Cash-Karp as a tableau, summed in the solver's order;
#   held  Cash-Karp, each step started at h |lambda_soil| <= 0.8 beta;
#   ark   ARK4(3)6L[2]SA (harness/ark436.R), the soil's drainage and
#         infiltration solved at each stage by a damped Newton.
#
#   PLANT_LIB=... NODES=108 TOL=1e-3 METHOD=ark [OUT=run.rds] [REF=u108.rds] \
#     [STATES=states.rds] [SWITCH_DAYS=0.05 [SWITCH_AT=0]] \
#     Rscript harness/ark_prototype.R
#
# REF compares the steps with a recording of harness/v12_steps.R at the same
# nodes and tolerance, which METHOD=ck reproduces bit for bit. STATES keeps the
# state at every accepted step. SWITCH_DAYS refuses a step longer than that
# across which a member's net production crosses SWITCH_AT, and halves it.
# Sourced, it defines the driver and does not run it.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
source(file.path(here, "long_drought.R"))
tab <- new.env()
sys.source(file.path(here, "ark436.R"), envir = tab)

nodes <- as.integer(Sys.getenv("NODES", "108"))
tol <- as.numeric(Sys.getenv("TOL", "1e-3"))
method <- match.arg(Sys.getenv("METHOD", "ck"), c("ck", "held", "ark"))
tb <- if (method == "ark") {
  with(tab, list(A = AE, AI = AI, b = b, d = d, c = cc, ord = 4))
} else {
  with(tab, list(A = ACK, b = bCK, d = dCK, c = cCK, ord = 5))
}

times <- uniform_times(nodes)
pulses <- sort(unique(AK))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
env <- mkenv()
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

n <- new.env()
for (x in c("evaluations", "members", "switch", "clamp", "floor", "accepted",
            "accepted_at_minimum", "rejected_inaccurate", "rejected_thrown",
            "rejected_refused", "rejected_switch", "solves", "iterations", "halvings", "failures")) {
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
    if (method == "ark") kI[[i]] <- stiff_rates(Y[blk], rain[i])
  }
  y1 <- combine(y, tb$b, k, h)
  at_end <- rates(y1, t + h)
  if (is.null(at_end)) return(NULL)
  list(y = y1, yerr = combine(0, tb$b - tb$d, k, h), rates = at_end, P = production(y1))
}

# OdeControl::adjust_step_size and reject_step. `shrank` persists between
# calls, as the solver's flag does where a step at the minimum cannot shrink.
ctl <- new.env()
ctl$shrank <- FALSE
reject <- function(h) {
  ctl$shrank <- TRUE
  max(h * 0.2, ct$ode_step_size_min)
}
adjust <- function(h, y, yerr, dydt) {
  level <- ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) +
    ct$ode_tol_abs
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
  if (rmax > 1.1) {
    hn <- max(h * max(0.2, 0.9 / rmax^(1 / tb$ord)), ct$ode_step_size_min)
    if (hn < h) {
      ctl$shrank <- TRUE
      h <- hn
    }
  } else if (rmax < 0.5) {
    h <- min(h * min(5, max(1, 0.9 / rmax^(1 / (tb$ord + 1)))), ct$ode_step_size_max)
    ctl$shrank <- FALSE
  } else {
    ctl$shrank <- FALSE
  }
  h
}

# SolverInternal::step, towards `target`: a step clipped to reach it lands on it
# and leaves the proposal as it was.
sv <- new.env()
steps <- new.env()
steps$k <- 0L
steps$states <- if (nzchar(Sys.getenv("STATES"))) list() else NULL
steps$rows <- matrix(NA_real_, 60000, 11,
                     dimnames = list(NULL, c("time", "h", "er", "ei", "M", "x_soil",
                                             paste0("soil_", 1:5))))
step <- function(target) {
  t0 <- sv$t
  remaining <- target - t0
  h <- sv$h_last
  if (method == "held") h <- min(h, 0.8 * BETA / lambda_soil(sv$y, t0))
  repeat {
    final <- h > remaining
    if (final) h <- remaining
    a <- attempt(t0, sv$y, sv$dydt, h)
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
      } else if (h > DELTA && any(sign(a$P) != sign(sv$P))) {
        hn <- max(h / 2, DELTA)
        ctl$shrank <- TRUE
        n$rejected_switch <- n$rejected_switch + 1
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
    steps$k <- steps$k + 1L
    if (steps$k > nrow(steps$rows)) steps$rows <- rbind(steps$rows, steps$rows * NA)
    steps$rows[steps$k, ] <- c(sv$t, h, ctl$ratio, ctl$index, (length(a$y) - 10) %/% 9,
                               h * lambda_soil(sv$y, t0) / BETA, a$y[soil(a$y)])
    if (!is.null(steps$states)) steps$states[[steps$k]] <- a$y
    sv$y <- a$y
    sv$dydt <- a$rates
    sv$P <- a$P
    return(invisible())
  }
}

if (sys.nframe() == 0L) {
  # SCM::run: each introduction is an entry, and the zero pulses between entries
  # are targets the steps land on.
  t_start <- proc.time()[["elapsed"]]
  sv$t <- 0
  sv$h_last <- ct$ode_step_size_initial
  for (k in seq_along(times)) {
    patch$introduce_new_node(1L, times[k])
    sv$y <- patch$ode_state
    sv$dydt <- rates(sv$y, sv$t)
    if (is.null(sv$dydt)) stop("an entry's rates raised DomainError")
    sv$P <- production(sv$y)
    t_end <- if (k < length(times)) times[k + 1] else LIFETIME
    for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
      while (sv$t < target) step(target)
    }
  }
  secs <- proc.time()[["elapsed"]] - t_start

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
                  "rejected_thrown", "rejected_refused", "rejected_switch"),
                function(x) n[[x]], 0)
  st <- as.data.frame(steps$rows[seq_len(steps$k), , drop = FALSE])
  cat(sprintf("%s nodes %d tol %g: J %.9f, %d accepted, %.0f s; %s\n", method, nodes, tol,
              J, att[["accepted"]], secs, paste(names(att), att, sep = "=", collapse = " ")))
  cat(sprintf("rate evaluations %d, member evaluations %d; evaluated states past the inflow switch %d, the loss clamp %d, the floor %d\n",
              n$evaluations, n$members, n$switch, n$clamp, n$floor))
  if (method == "ark") {
    cat(sprintf("block solves %d: %.2f Newton iterations each, at most %d; %d halvings; %d failures\n",
                n$solves, n$iterations / max(1, n$solves - n$failures), n$most_iterations,
                n$halvings, n$failures))
  }
  NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
            "storage", "offspring", "log_density", "mass")
  ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
  kind <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  pct <- function(x) sprintf("%.1f%%", 100 * mean(x, na.rm = TRUE))
  cat("binding: soil", pct(grepl("^soil_", kind)), " accumulator", pct(grepl("^accumulator_", kind)),
      " member", pct(kind %in% NODE), " storage", pct(kind == "storage"),
      "; h |lambda_soil| / beta at the start >= 0.8:", pct(st$x_soil >= 0.8),
      " > 1:", pct(st$x_soil > 1), "\n")

  if (nzchar(Sys.getenv("REF"))) {
    ref <- readRDS(Sys.getenv("REF"))
    rs <- ref$st
    ref$attempts[["rejected_switch"]] <- 0
    same <- nrow(rs) == nrow(st) && identical(rs$time, st$time) && identical(rs$h, st$h) &&
      identical(rs$er, st$er) && identical(as.numeric(rs$ei), st$ei)
    cat(sprintf("against the recording: J %s, attempts %s, steps %s\n",
                if (identical(ref$J, J)) "identical" else sprintf("differs by %.3g", J - ref$J),
                if (identical(as.numeric(ref$attempts[names(att)]), as.numeric(att))) "identical" else "differ",
                if (same) "identical" else "differ"))
  }
  if (!is.null(steps$states)) saveRDS(steps$states, Sys.getenv("STATES"), compress = FALSE)
  if (nzchar(Sys.getenv("OUT"))) {
    saveRDS(list(method = method, nodes = nodes, tol = tol, J = J, attempts = att,
                 counts = as.list(n), secs = secs, st = st,
                 by_node = data.frame(time = sp$node_times, weight = w[-length(w)],
                                      fecundity = f, patch_density = pd)),
            Sys.getenv("OUT"))
  }
}
