# Invader members stepped on their own in the resident's field, held fixed.
#
# The field at any time is rebuilt from the resident recording (run_resident.sh):
# the resident state is the cubic Hermite interpolant of the step that holds the
# time, through the recorded states and the rates there, and a resident patch set
# to that state builds the light and soil field. An invader member is a node of a
# species holding only invader members, rated in a copy of that field: the
# member's growth, water use and mortality are its own, and it adds nothing to
# the field, as in plant's invader walk. The two rates a node carries on the
# birth-date path beside its six (interval_establishment and its moment) are zero
# for an introduced node, so a member is seven states:
#   height, mortality, fecundity, area_heartwood, mass_heartwood, storage,
#   offspring_produced_survival_weighted.
# Sourced; reads REC (recording basename), REGIME, INVADERS and MEMBERS.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods"
D <- dirname(S)
REC <- Sys.getenv("REC", "ld_ruleA")
REGIME <- Sys.getenv("REGIME", "long-drought")
INVADERS <- strsplit(Sys.getenv("INVADERS", "lma=2,lma=0.5,hmat=0.5,hmat=2"), ",")[[1]]
MEMBERS <- as.integer(strsplit(Sys.getenv("MEMBERS", "1,3,6,10,15,20,25,30,40,50,60,70,80,90,100"), ",")[[1]])
source(file.path(S, "snap/harness/long_drought.R"))
STATE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
           "storage", "offspring")
I_MORT <- 2L
I_STORE <- 6L
I_OFF <- 7L
TAU_S <- 7 / 365
DAY <- 1 / 365

rec <- readRDS(file.path(S, paste0(REC, ".rds")))
states <- readRDS(file.path(S, paste0(REC, "_states.rds")))
st <- rec$st
K <- nrow(st)
t_end <- st$time
t_beg <- c(0, t_end[-K])
nk <- (lengths(states) - 10L) %/% 9L
times <- readRDS(file.path(D, "window/t/t_u108.rds"))
k_intro <- match(seq_along(times), nk)
stopifnot(identical(t_beg[k_intro], times))

p_res <- stand_at(times)
ct <- control()
ct$ode_tol_rel <- 3e-5
ct$ode_tol_abs <- 1e-4 * 3e-5
ct$node_density_in_birth_date <- TRUE
env_full <- mkenv(REGIME)
# The field does not read rainfall (only the soil's own rates do), and copying a
# 41-year driver costs 5 ms an environment; the field patch carries a constant.
env_const <- Environment("TF24")
env_const$extrinsic_drivers_set_constant("rainfall", 0)

# A resident patch holding the first n nodes, each introduced where the driver
# introduced it; the state just after each introduction is the next step's start.
y0_intro <- vector("list", length(times))
build_patch <- function(n, e) {
  pa <- plant:::Patch("TF24", "TF24_Env")(p_res, e, ct)
  pa$introduce_new_node(1L, times[1])
  if (is.null(y0_intro[[1]])) y0_intro[[1]] <<- pa$ode_state
  for (j in seq_len(n)[-1]) {
    pa$set_ode_state(states[[k_intro[j] - 1L]], times[j])
    pa$introduce_new_node(1L, times[j])
    if (is.null(y0_intro[[j]])) y0_intro[[j]] <<- pa$ode_state
  }
  pa
}
# Kind "d" carries the record's rainfall, for the resident's rates; kind "f" the
# constant, for the field. A few of each are kept.
patches <- new.env()
get_patch <- function(n, kind) {
  key <- paste0(kind, n)
  if (is.null(patches[[key]])) {
    held <- grep(paste0("^", kind), ls(patches), value = TRUE)
    if (length(held) >= 3) rm(list = held[seq_len(length(held) - 2)], envir = patches)
    patches[[key]] <- build_patch(n, if (kind == "d") env_full else env_const)
  }
  patches[[key]]
}

# Step k runs from t_beg[k] to t_end[k] holding nk[k] nodes.
y_beg <- function(k) {
  if (k == 1L || nk[k] != nk[k - 1L]) {
    get_patch(nk[k], "d")
    y0_intro[[nk[k]]]
  } else {
    states[[k - 1L]]
  }
}
fmemo <- new.env()
memo <- function(key, f) {
  if (is.null(fmemo[[key]])) {
    if (length(ls(fmemo)) > 64) rm(list = ls(fmemo), envir = fmemo)
    fmemo[[key]] <- f()
  }
  fmemo[[key]]
}
f_end <- function(k) memo(paste0("e", k), function() get_patch(nk[k], "d")$derivs(states[[k]], t_end[k]))
f_beg <- function(k) {
  if (k > 1L && nk[k] == nk[k - 1L]) return(f_end(k - 1L))
  memo(paste0("b", k), function() get_patch(nk[k], "d")$derivs(y_beg(k), t_beg[k]))
}
step_data <- function(k) {
  list(k = k, t0 = t_beg[k], h = t_end[k] - t_beg[k], y0 = y_beg(k), f0 = f_beg(k),
       y1 = states[[k]], f1 = f_end(k))
}
# The step that holds tau: the last that starts at or before it, so an
# introduction time belongs to the step after the introduction.
step_of <- function(tau) min(findInterval(tau, t_beg), K)
hermite <- function(sd, tau) {
  u <- (tau - sd$t0) / sd$h
  h <- sd$h
  (1 + 2 * u) * (1 - u)^2 * sd$y0 + u * (1 - u)^2 * h * sd$f0 +
    u^2 * (3 - 2 * u) * sd$y1 + u^2 * (u - 1) * h * sd$f1
}
counts <- new.env()
counts$fields <- 0
counts$members <- 0
# The field at tau, with the patch survival there. sd defaults to tau's step.
field_at <- function(tau, sd = NULL) {
  if (is.null(sd) || tau < sd$t0 || tau > sd$t0 + sd$h) sd <- step_data(step_of(tau))
  pf <- get_patch(nk[sd$k], "f")
  pf$set_ode_state(hermite(sd, tau), tau)
  counts$fields <- counts$fields + 1
  list(env = pf$environment, pr = pf$pr_survival(tau), tau = tau)
}

# The invaders: each a species holding its members in birth order, from a patch
# built as run_record.R's INVADERS builds one (stand_at) for scm$run_mutant.
make_invader <- function(spec) {
  kv <- strsplit(spec, "=")[[1]]
  q <- stand_at(times, kv[1], as.numeric(kv[2]))
  tpl <- plant:::Patch("TF24", "TF24_Env")(q, env_const, ct)
  list(name = spec, q = q, tpl = tpl, sp = tpl$species[[1]], pars = q$strategies[[1]]$pars,
       birth = numeric(), node = integer(), nodes = list())
}
INV <- lapply(INVADERS, make_invader)
names(INV) <- INVADERS
birth_rate <- function(i, tau) INV[[i]]$sp$extrinsic_drivers$evaluate("birth_rate", tau)

# The pool's capacity, TF24_Strategy::storage_capacity from height.
capacity <- function(i, h) {
  pars <- INV[[i]]$pars
  eta_c <- 1 - 2 / (1 + pars$eta) + 1 / (1 + 2 * pars$eta)
  pars$a_st1 * pars$theta * (h / pars$a_l1)^(1 / pars$a_l2) * h * eta_c * pars$rho
}

# A member born at tau joins invader i: its initial state is the boundary node's
# in the field there. A standalone node seeded the same way is kept beside it, to
# rate the member alone where the species as a whole raises.
add_member <- function(i, Y, tau, node, fld = NULL) {
  if (is.null(fld)) fld <- field_at(tau)
  sp <- INV[[i]]$sp
  if (ncol(Y) > 0) sp$ode_state <- as.vector(rbind(Y, 0, 0))
  br <- birth_rate(i, tau)
  sp$compute_rates(fld$env, fld$pr, br)
  sp$introduce_new_node()
  nd <- INV[[i]]$tpl$species[[1]]$new_node
  nd$compute_initial_conditions(fld$env, fld$pr, br)
  INV[[i]]$birth <<- c(INV[[i]]$birth, tau)
  INV[[i]]$node <<- c(INV[[i]]$node, node)
  INV[[i]]$nodes[[length(INV[[i]]$nodes) + 1L]] <<- nd
  y_new <- matrix(sp$ode_state, 9)[1:7, sp$size]
  stopifnot(identical(y_new, nd$ode_state[1:7]))
  cbind(Y, y_new)
}
# Rebuild invader i's species with members born at `births` (nodes `node`), for a
# walk that starts from recorded member states.
reset_invader <- function(i, births, node) {
  INV[[i]]$sp <<- INV[[i]]$tpl$species[[1]]
  INV[[i]]$birth <<- numeric()
  INV[[i]]$node <<- integer()
  INV[[i]]$nodes <<- list()
  Y <- matrix(0, 7, 0)
  for (m in seq_along(births)) Y <- add_member(i, Y, births[m], node[m])
  Y
}

# The members' rates at tau: one 7 x M matrix per invader, NaN for a member whose
# state is not finite or whose rating raised, with the message kept.
rates_at <- function(tau, Y, fld = NULL, sd = NULL) {
  if (is.null(fld)) fld <- field_at(tau, sd)
  out <- vector("list", length(Y))
  msg <- vector("list", length(Y))
  for (i in seq_along(Y)) {
    M <- ncol(Y[[i]])
    msg[[i]] <- rep(NA_character_, M)
    if (M == 0) { out[[i]] <- matrix(0, 7, 0); next }
    ok <- apply(is.finite(Y[[i]]), 2, all)
    Yi <- Y[[i]]
    Yi[, !ok] <- 1  # a placeholder the species can rate; its rates are discarded
    msg[[i]][!ok] <- "non-finite state"
    br <- birth_rate(i, tau)
    sp <- INV[[i]]$sp
    r <- tryCatch({
      sp$ode_state <- as.vector(rbind(Yi, 0, 0))
      sp$compute_rates(fld$env, fld$pr, br)
      matrix(sp$ode_rates, 9)[1:7, , drop = FALSE]
    }, error = function(e) NULL)
    if (is.null(r)) {
      r <- matrix(NaN, 7, M)
      for (m in which(ok)) {
        nd <- INV[[i]]$nodes[[m]]
        r[, m] <- tryCatch({
          nd$ode_state <- c(Yi[, m], 0, 0)
          nd$compute_rates(fld$env, fld$pr)
          nd$ode_rates[1:7]
        }, error = function(e) { msg[[i]][m] <<- conditionMessage(e); rep(NaN, 7) })
      }
    }
    r[, !ok] <- NaN
    bad <- ok & !apply(is.finite(r), 2, all)
    msg[[i]][bad & is.na(msg[[i]])] <- "non-finite rate"
    counts$members <- counts$members + M
    out[[i]] <- r
  }
  attr(out, "msg") <- msg
  out
}

# Arithmetic on lists of matrices.
lin <- function(Y, h, coef, Kl) {
  out <- Y
  for (i in seq_along(Y)) {
    acc <- Y[[i]]
    for (j in seq_along(coef)) if (coef[j] != 0) acc <- acc + (h * coef[j]) * Kl[[j]][[i]]
    out[[i]] <- acc
  }
  out
}

lower <- function(rows) {
  s <- length(rows)
  A <- matrix(0, s, s)
  for (i in seq_len(s)) A[i, seq_along(rows[[i]])] <- rows[[i]]
  A
}
ark <- new.env()
sys.source(file.path(S, "snap/harness/ark436.R"), envir = ark)
# Dormand-Prince's and Tsitouras's tableaux, and RODAS's stage coefficients, are
# harness/stability.R's. Their last explicit stage is the result (FSAL), which a
# caller rates as the end of the step instead.
stab <- new.env()
local({
  wd <- setwd(file.path(S, "snap"))
  on.exit(setwd(wd))
  sys.source("harness/stability.R", envir = stab)
})
erk_of <- function(name, evals) {
  e <- environment(stab$methods[[name]]$run)
  s <- nrow(e$A) - 1L
  A <- e$A[seq_len(s), seq_len(s)]
  list(A = A, b = e$b[seq_len(s)], c = rowSums(A), evals = evals)
}
TABLEAU <- list(
  ck = list(A = ark$ACK, b = ark$bCK, d = ark$dCK, c = ark$cCK, evals = 6),
  dp = erk_of("Dormand-Prince 5(4)", 6),
  tsit = erk_of("Tsitouras 5(4)", 6))
stopifnot(all(abs(rowSums(TABLEAU$ck$A) - TABLEAU$ck$c) < 1e-14),
          abs(TABLEAU$dp$c[6] - 1) < 1e-14, abs(TABLEAU$tsit$c[6] - 1) < 1e-12,
          abs(sum(TABLEAU$dp$b) - 1) < 1e-14, abs(sum(TABLEAU$tsit$b) - 1) < 1e-12)

# One step of each method from (t0, Y0), whose rates K0 are given. Each returns
# the end state, the state at every stage where the rates were taken (the end
# included, where the next step's first rates are taken), the rates there, and
# the member evaluations the step spent. `rates` is rates_at or a stand-in.
step_erk <- function(tab, t0, h, Y0, K0, rates) {
  s <- length(tab$b)
  Kl <- list(K0)
  Ys <- list(Y0)
  msgs <- list(attr(K0, "msg"))
  for (i in 2:s) {
    Ys[[i]] <- lin(Y0, h, tab$A[i, 1:(i - 1)], Kl)
    Kl[[i]] <- rates(t0 + tab$c[i] * h, Ys[[i]])
    msgs[[i]] <- attr(Kl[[i]], "msg")
  }
  Y1 <- lin(Y0, h, tab$b, Kl)
  list(Y1 = Y1, Ys = Ys, Kl = Kl, msgs = msgs, cs = tab$c, evals = tab$evals)
}
# Ketcheson's SSPRK(10,4), low-storage: ten forward-Euler stages of h/6.
step_ssprk <- function(t0, h, Y0, K0, rates) {
  q1 <- Y0; q2 <- Y0; Ys <- list(); Kl <- list(); msgs <- list(); cs <- numeric()
  cq <- 0
  stage <- function(Y, c, K = NULL) {
    if (is.null(K)) K <- rates(t0 + c * h, Y)
    Ys[[length(Ys) + 1L]] <<- Y; Kl[[length(Kl) + 1L]] <<- K
    msgs[[length(msgs) + 1L]] <<- attr(K, "msg"); cs <<- c(cs, c)
    K
  }
  for (i in 1:5) {
    K <- stage(q1, cq, if (i == 1) K0)
    q1 <- lin(q1, h / 6, 1, list(K)); cq <- cq + 1 / 6
  }
  q2 <- lin(lapply(q2, `*`, 1 / 25), 9 / 25, 1, list(q1))
  q1 <- mapply(function(a, b) 15 * a - 5 * b, q2, q1, SIMPLIFY = FALSE)
  cq <- 15 * (9 / 25 * 5 / 6) - 5 * (5 / 6)
  for (i in 6:9) {
    K <- stage(q1, cq)
    q1 <- lin(q1, h / 6, 1, list(K)); cq <- cq + 1 / 6
  }
  K <- stage(q1, cq)
  Y1 <- mapply(function(a, b, k) a + 3 / 5 * b + h / 10 * k, q2, q1, K, SIMPLIFY = FALSE)
  list(Y1 = Y1, Ys = Ys, Kl = Kl, msgs = msgs, cs = cs, evals = 10)
}
# odelia's RODAS (rodas.f, METH = 1), with each member's Jacobian by forward
# differences: a relative step 1e-7 |y|, floored for the pool at 1e-6 of its
# capacity and for mortality at 1e-2, and df/dt by a forward difference in time
# of 1e-7 (|t| + 1), as odelia takes it. Members are independent, so one
# perturbed rating per state gives that column for every member.
RODAS <- local({
  e <- environment(stab$methods[["RODAS (implicit)"]]$run)
  # The time nodes and the df/dt weights, which the autonomous test equation does
  # not need, are odelia's (ode_step_rodas.hpp).
  list(gamma = e$gamma, a = e$a, cc = e$cc, c = c(0, 0.386, 0.21, 0.63, 1, 1),
       d = c(0.25, -0.1043, 0.1035, -0.03620000000000023, 0, 0))
})
jacobians <- function(t0, Y0, K0, rates, fld0) {
  J <- lapply(Y0, function(Y) array(0, c(7, 7, ncol(Y))))
  for (s in 1:7) {
    dl <- lapply(seq_along(Y0), function(i) {
      y <- Y0[[i]][s, ]
      fl <- if (s == I_STORE) 1e-6 * capacity(i, Y0[[i]][1, ]) else if (s == I_MORT) 1e-2 else 0
      dy <- 1e-7 * pmax(abs(y), fl)
      dy[dy == 0] <- 1e-12
      (y + dy) - y
    })
    Yp <- Y0
    for (i in seq_along(Y0)) Yp[[i]][s, ] <- Y0[[i]][s, ] + dl[[i]]
    Kp <- rates(t0, Yp, fld0)
    for (i in seq_along(Y0)) {
      if (ncol(Y0[[i]]) == 0) next
      J[[i]][, s, ] <- sweep(Kp[[i]] - K0[[i]], 2, dl[[i]], `/`)
    }
  }
  J
}
# The start's Jacobians and df/dt, which every step length from it shares.
rodas_prep <- function(t0, Y0, K0, rates, fld0) {
  J <- jacobians(t0, Y0, K0, rates, fld0)
  dt <- 1e-7 * (abs(t0) + 1)
  Kt <- rates(t0 + dt, Y0)
  list(J = J, dT = mapply(function(a, b) (a - b) / dt, Kt, K0, SIMPLIFY = FALSE))
}
step_rodas <- function(t0, h, Y0, K0, rates, prep) {
  J <- prep$J
  dT <- prep$dT
  W <-lapply(J, function(Ji) { for (m in seq_len(dim(Ji)[3])) Ji[, , m] <- diag(7) / (h * RODAS$gamma) - Ji[, , m]; Ji })
  solve_all <- function(rhs) mapply(function(Wi, ri) {
    if (ncol(ri) == 0) return(ri)
    vapply(seq_len(ncol(ri)), function(m) tryCatch(solve(Wi[, , m], ri[, m]), error = function(e) rep(NaN, 7)), numeric(7))
  }, W, rhs, SIMPLIFY = FALSE)
  k <- list(); args <- list(Y0); Kl <- list(K0); msgs <- list(attr(K0, "msg"))
  rhs <- mapply(function(f, g) f + h * RODAS$d[1] * g, K0, dT, SIMPLIFY = FALSE)
  k[[1]] <- solve_all(rhs)
  for (i in 2:6) {
    if (i <= 5) {
      args[[i]] <- lin(Y0, 1, RODAS$a[i, 1:(i - 1)], k)
    } else {
      args[[i]] <- mapply(`+`, args[[5]], k[[5]], SIMPLIFY = FALSE)
    }
    Kl[[i]] <- rates(t0 + RODAS$c[i] * h, args[[i]])
    msgs[[i]] <- attr(Kl[[i]], "msg")
    rhs <- Kl[[i]]
    for (ii in seq_along(rhs)) {
      acc <- rhs[[ii]] + h * RODAS$d[i] * dT[[ii]]
      for (j in 1:(i - 1)) acc <- acc + RODAS$cc[i, j] / h * k[[j]][[ii]]
      rhs[[ii]] <- acc
    }
    k[[i]] <- solve_all(rhs)
  }
  Y1 <- mapply(`+`, args[[6]], k[[6]], SIMPLIFY = FALSE)
  list(Y1 = Y1, Ys = args, Kl = Kl, msgs = msgs, cs = RODAS$c, evals = 6 + 7 + 1, J = J)
}

# Cash-Karp with step-size control towards `t1`, the field of step `sd`, used
# for the references; returns the state at t1 and the proposal carried on.
# Each member state is held to rtol of its size, mortality to rtol absolute, and
# the pool to rtol of its size plus 1e-6 of its capacity.
ref_levels <- function(Y0, Y1) {
  lapply(seq_along(Y0), function(i) {
    a <- pmax(abs(Y0[[i]]), abs(Y1[[i]]))
    if (ncol(a) == 0) return(a)
    a[I_MORT, ] <- pmax(a[I_MORT, ], 1)
    a[I_STORE, ] <- a[I_STORE, ] + 1e-6 * capacity(i, Y1[[i]][1, ])
    pmax(a, 1e-300)
  })
}
ck_to <- function(t0, t1, Y0, sd, h, rtol, stats) {
  tab <- TABLEAU$ck
  t <- t0
  Y <- Y0
  K0 <- rates_at(t, Y, sd = sd)
  while (t < t1) {
    hh <- min(h, t1 - t)
    last <- hh >= t1 - t
    r <- step_erk(tab, t, hh, Y, K0, function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld, sd))
    E <- lin(lapply(Y, `*`, 0), hh, tab$b - tab$d, r$Kl)
    L <- ref_levels(Y, r$Y1)
    ratio <- max(vapply(seq_along(E), function(i) if (length(E[[i]])) max(abs(E[[i]]) / L[[i]]) else 0, 0)) / rtol
    if (!is.finite(ratio)) stop(sprintf("reference: non-finite error at t = %.10f", t))
    if (ratio > 1) {
      h <- hh * max(0.2, 0.9 * ratio^(-1 / 4))
      stats$rejected <- stats$rejected + 1
      next
    }
    stats$accepted <- stats$accepted + 1
    t <- if (last) t1 else t + hh
    Y <- r$Y1
    K0 <- rates_at(t, Y, sd = sd)
    hn <- hh * min(5, max(0.2, 0.9 * max(ratio, 1e-10)^(-1 / 5)))
    if (!last || hn < h) h <- hn
  }
  list(Y = Y, h = h)
}

# Fixed Cash-Karp sub-steps of at most hmax inside each resident step, from
# (t0, Y0) to every time in `outs`; returns the state at each.
ck_fixed <- function(t0, Y0, outs, hmax) {
  tab <- TABLEAU$ck
  t_last <- max(outs)
  ks <- step_of(t0):step_of(t_last)
  cuts <- sort(unique(c(t0, outs, t_end[ks], t_beg[ks])))
  cuts <- cuts[cuts >= t0 & cuts <= t_last]
  res <- list()
  Y <- Y0
  for (s in seq_len(length(cuts) - 1L)) {
    a <- cuts[s]; b <- cuts[s + 1L]
    sd <- step_data(step_of(a))
    n <- max(1L, ceiling((b - a) / hmax - 1e-9))
    hh <- (b - a) / n
    t <- a
    for (m in seq_len(n)) {
      K0 <- rates_at(t, Y, sd = sd)
      r <- step_erk(tab, t, hh, Y, K0, function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld, sd))
      Y <- r$Y1
      t <- if (m == n) b else a + m * hh
    }
    if (any(abs(outs - b) < 1e-12)) res[[sprintf("%.10f", b)]] <- Y
  }
  res
}
