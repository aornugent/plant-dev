# Single steps of each method from the reference's state at each test start: 7,
# 15, 22, 26, 31 and 38 days, by Cash-Karp, Dormand-Prince, Tsitouras 5(4),
# SSPRK(10,4) and RODAS, every member of every invader at once, in the resident's
# field. One row per (start, step, method, invader, member):
#   raised       a rating raised or went non-finite, at a stage or at the end;
#                raise_stage, raise_state and raise_msg say where;
#   plant_raise  a stage state (the end included) whose density plant refuses:
#                log density = log(birth rate) - mortality above 50, or not finite
#                (Patch::check_finite_ode_state, run on every set_ode_state);
#   min_rel_*    each state's lowest stage value over its start value;
#   min_r        the pool's lowest fill (storage over capacity) at a stage;
#   mort_rate_max the largest mortality rate at a stage (/yr);
#   err_*        the end state against the reference: relative, the pool's
#                against its capacity, mortality's absolute (a survival factor),
#                the offspring increment's relative to the reference increment
#                and to the member's offspring at t = 40, and the driver's norm
#                at the tied 3e-5 (above 1 is beyond that tolerance);
#   evals        member ratings a step spends in a run: 6 for the pairs, 10 for
#                SSPRK(10,4), 6 + 7 Jacobian columns + 1 for df/dt for RODAS;
#   and, at the start, the pool's fill r0, net production P0, tau_eff =
#   tau_s + S_max / (charge + drain), the pool's own linear time -1/J_SS, and the
#   fill the flows relax towards, rstar.
#
#   PLANT_LIB=$DEV/lib_guard [REC=ld_ruleA] [PASS1=pass1_ld_ruleA.rds] \
#     [OUT=steps_ld_ruleA.rds] Rscript steps.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
P1 <- readRDS(file.path(S, Sys.getenv("PASS1", paste0("pass1_", REC, ".rds"))))
OUT <- file.path(S, Sys.getenv("OUT", paste0("steps_", REC, ".rds")))
stopifnot(identical(P1$invaders, INVADERS))
starts <- P1$starts
if (nzchar(Sys.getenv("STARTS"))) starts <- starts[as.integer(strsplit(Sys.getenv("STARTS"), ",")[[1]]), ]
H <- P1$h_days
key <- function(t) sprintf("%.10f", t)
METHODS <- c("ck", "dp", "tsit", "ssprk", "rodas")
EVALS <- c(ck = 6, dp = 6, tsit = 6, ssprk = 10, rodas = 14)
O40 <- P1$saved[[key(40)]]
TOL <- 3e-5

rates_fn <- function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld)
net_production <- function(i) vapply(INV[[i]]$sp$nodes, function(nd) nd$individual$aux("net_mass_production_dt"), 0)

rows <- list()
t_clock <- proc.time()[["elapsed"]]
for (si in seq_len(nrow(starts))) {
  t0 <- starts$t0[si]
  Y0 <- P1$saved[[key(t0)]]
  for (i in seq_along(INV)) {
    M <- ncol(Y0[[i]])
    reset_invader(i, P1$members[[i]]$birth[seq_len(M)], P1$members[[i]]$node[seq_len(M)])
  }
  fld0 <- field_at(t0)
  K0 <- rates_at(t0, Y0, fld0)
  P0 <- lapply(seq_along(INV), net_production)
  prep <- rodas_prep(t0, Y0, K0, rates_fn, fld0)
  start_of <- lapply(seq_along(INV), function(i) {
    pars <- INV[[i]]$pars
    y <- Y0[[i]]
    cap <- capacity(i, y[1, ])
    r0 <- y[I_STORE, ] / cap
    P <- P0[[i]]
    Ppos <- 0.5 * (P + sqrt(P^2 + 1e-8))
    G <- 1 / (1 + exp(-(r0 - pars$a_st2) / 0.1))
    flow <- Ppos * (1 - G) + (Ppos - P)
    data.frame(invader = INVADERS[i], node = INV[[i]]$node, birth = INV[[i]]$birth, height0 = y[1, ],
               cap0 = cap, r0 = r0, P0 = P, rstar = Ppos * (1 - G) / flow,
               tau_eff_d = (TAU_S + cap / flow) * 365,
               tau_J_d = -1 / prep$J[[i]][I_STORE, I_STORE, ] * 365, mort0 = y[I_MORT, ])
  })
  for (hd in H) {
    h <- hd * DAY
    Yend <- P1$saved[[key(t0 + h)]]
    Yref <- lapply(seq_along(Y0), function(i) Yend[[i]][, seq_len(ncol(Y0[[i]])), drop = FALSE])
    for (meth in METHODS) {
      res <- switch(meth,
                    ck = step_erk(TABLEAU$ck, t0, h, Y0, K0, rates_fn),
                    dp = step_erk(TABLEAU$dp, t0, h, Y0, K0, rates_fn),
                    tsit = step_erk(TABLEAU$tsit, t0, h, Y0, K0, rates_fn),
                    ssprk = step_ssprk(t0, h, Y0, K0, rates_fn),
                    rodas = step_rodas(t0, h, Y0, K0, rates_fn, prep))
      Kend <- rates_at(t0 + h, res$Y1)
      ns <- length(res$Ys)
      for (i in seq_along(INV)) {
        M <- ncol(Y0[[i]])
        if (M == 0) next
        # stages, the end last: n x 7 x M
        Ys <- array(NA_real_, c(ns + 1L, 7, M))
        Ks <- array(NA_real_, c(ns + 1L, 7, M))
        for (s in seq_len(ns)) { Ys[s, , ] <- res$Ys[[s]][[i]]; Ks[s, , ] <- res$Kl[[s]][[i]] }
        Ys[ns + 1L, , ] <- res$Y1[[i]]
        Ks[ns + 1L, , ] <- Kend[[i]]
        msg <- rbind(do.call(rbind, lapply(res$msgs, `[[`, i)), attr(Kend, "msg")[[i]])
        bad_stage <- apply(!is.finite(Ys) | !is.finite(Ks), c(1, 3), any) | !is.na(msg)
        raised <- apply(bad_stage, 2, any)
        raise_stage <- apply(bad_stage, 2, function(v) if (any(v)) which(v)[1] else NA_integer_)
        raise_msg <- vapply(seq_len(M), function(m) if (is.na(raise_stage[m])) NA_character_ else
          { x <- msg[raise_stage[m], m]; if (is.na(x)) "non-finite stage value" else x }, "")
        raise_state <- vapply(seq_len(M), function(m) {
          s <- raise_stage[m]
          if (is.na(s)) return(NA_character_)
          w <- which(!is.finite(Ys[s, , m]) | !is.finite(Ks[s, , m]))
          if (length(w)) paste(STATE[w], collapse = "+") else NA_character_
        }, "")
        logd <- log(birth_rate(i, t0)) - Ys[, I_MORT, , drop = FALSE][, 1, ]
        logd <- matrix(logd, ns + 1L)
        pr_bad <- !is.finite(logd) | logd > 50
        plant_raise <- apply(pr_bad, 2, any)
        plant_stage <- apply(pr_bad, 2, function(v) if (any(v)) which(v)[1] else NA_integer_)
        y0 <- Y0[[i]]
        rel <- function(s) apply(matrix(Ys[, s, ], ns + 1L), 2, min) / y0[s, ]
        cap_s <- matrix(capacity(i, pmax(Ys[, 1, ], 0)), ns + 1L)
        min_r <- apply(matrix(Ys[, I_STORE, ], ns + 1L) / cap_s, 2, min)
        y1 <- res$Y1[[i]]
        yr <- Yref[[i]]
        err <- abs(y1 - yr) / abs(yr)
        norm <- apply(abs(y1 - yr) / (TOL * abs(yr) + 1e-4 * TOL), 2, max)
        inc_ref <- yr[I_OFF, ] - y0[I_OFF, ]
        inc <- y1[I_OFF, ] - y0[I_OFF, ]
        rows[[length(rows) + 1L]] <- cbind(
          data.frame(t0 = t0, kind = starts$kind[si], h_days = hd, method = meth, evals = EVALS[[meth]]),
          start_of[[i]],
          data.frame(raised = raised, raise_stage = raise_stage, raise_state = raise_state, raise_msg = raise_msg,
                     plant_raise = plant_raise, plant_stage = plant_stage, n_stages = ns,
                     min_rel_S = rel(I_STORE), min_r = min_r, min_rel_h = rel(1), min_rel_mort = rel(I_MORT),
                     mort_rate_max = apply(matrix(Ks[, I_MORT, ], ns + 1L), 2, max),
                     err_h = err[1, ], err_mort_abs = abs(y1[I_MORT, ] - yr[I_MORT, ]), err_S_rel = err[I_STORE, ],
                     err_S_cap = abs(y1[I_STORE, ] - yr[I_STORE, ]) / capacity(i, yr[1, ]),
                     err_fec = err[3, ], err_off_inc = abs(inc - inc_ref) / abs(inc_ref),
                     err_off_O40 = abs(inc - inc_ref) / abs(O40[[i]][I_OFF, seq_len(M)]),
                     err_norm = norm, S_ref1 = yr[I_STORE, ], mort_ref1 = yr[I_MORT, ]))
      }
    }
  }
  cat(sprintf("start %d/%d t0 %.5f (%s): %d members, %.0f s\n", si, nrow(starts), t0, starts$kind[si],
              sum(vapply(Y0, ncol, 0)), proc.time()[["elapsed"]] - t_clock))
}
out <- do.call(rbind, rows)
rownames(out) <- NULL
saveRDS(out, OUT, compress = "xz")
cat(sprintf("done: %d rows, %d fields, %.0f member ratings, %.0f s\n", nrow(out), counts$fields, counts$members,
            proc.time()[["elapsed"]] - t_clock))
