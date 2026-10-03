# An invader's walk at member level: every member of one invader stepped once per
# resident step of the recording, with no error control, from its birth to
# t = 40, as plant's walk steps them, by one method. The field at a stage is the
# Hermite interpolant's (plant's walk reads the resident's own stage fields).
# Each member is followed until plant would refuse its state (log density above
# 50, or not finite) or a rating raises; the member is then dropped and the walk
# goes on, so every such member is found. For each one: when, on which step, at
# which stage, and its pool, net production and tau_eff at that step's start.
# Also the largest h / tau_eff any member met, and the steps the walk took past
# each method's limits on y' = -y/tau.
#   PLANT_LIB=$DEV/lib_guard [REC=ld_ruleA] [REGIME=long-drought] INVADER=lma=2 \
#     [METHOD=ck|dp|tsit|ssprk|rodas] [NODES=1:108] [OUT=walk_....rds] Rscript walk.R
INVADER <- Sys.getenv("INVADER", "lma=2")
Sys.setenv(INVADERS = INVADER)
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
METHOD <- Sys.getenv("METHOD", "ck")
NODES <- eval(parse(text = Sys.getenv("NODES", "1:108")))
OUT <- file.path(S, Sys.getenv("OUT", sprintf("walk_%s_%s_%s.rds", REC, INVADER, METHOD)))
rates_fn <- function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld)
step_one <- function(t0, h, Y0, K0, fld0) switch(METHOD,
  ck = step_erk(TABLEAU$ck, t0, h, Y0, K0, rates_fn),
  dp = step_erk(TABLEAU$dp, t0, h, Y0, K0, rates_fn),
  tsit = step_erk(TABLEAU$tsit, t0, h, Y0, K0, rates_fn),
  ssprk = step_ssprk(t0, h, Y0, K0, rates_fn),
  rodas = step_rodas(t0, h, Y0, K0, rates_fn, rodas_prep(t0, Y0, K0, rates_fn, fld0)))

Y <- list(matrix(0, 7, 0))
alive <- logical()
events <- list()
kills <- list()
xmax <- data.frame(x = numeric(), t0 = numeric(), h_days = numeric(), node = integer())
worst <- list(x = 0)
t_clock <- proc.time()[["elapsed"]]
for (k in seq_len(K)) {
  sd <- step_data(k)
  if (k %in% k_intro[NODES]) {
    Y[[1]] <- add_member(1, Y[[1]], t_beg[k], match(k, k_intro), field_at(t_beg[k], sd))
    alive <- c(alive, TRUE)
  }
  M <- ncol(Y[[1]])
  if (M == 0) next
  h <- t_end[k] - t_beg[k]
  rates_k <- function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld, sd)
  rates_fn <- rates_k
  fld0 <- field_at(t_beg[k], sd)
  K0 <- rates_at(t_beg[k], Y, fld0)
  P <- vapply(INV[[1]]$sp$nodes, function(nd) nd$individual$aux("net_mass_production_dt"), 0)
  y <- Y[[1]]
  cap <- capacity(1, y[1, ])
  r0 <- y[I_STORE, ] / cap
  Ppos <- 0.5 * (P + sqrt(P^2 + 1e-8))
  G <- 1 / (1 + exp(-(r0 - INV[[1]]$pars$a_st2) / 0.1))
  tau_eff <- TAU_S + cap / (Ppos * (1 - G) + Ppos - P)
  x <- ifelse(alive, h / tau_eff, NA)
  if (any(alive) && max(x, na.rm = TRUE) > worst$x) {
    j <- which.max(x)
    worst <- list(x = x[j], t0 = t_beg[k], h_days = h * 365, node = INV[[1]]$node[j], r0 = r0[j], P0 = P[j])
  }
  res <- step_one(t_beg[k], h, Y, K0, fld0)
  Kend <- rates_at(t_end[k], res$Y1, sd = sd)
  ns <- length(res$Ys)
  mort <- rbind(do.call(rbind, lapply(res$Ys, function(z) z[[1]][I_MORT, ])), res$Y1[[1]][I_MORT, ])
  mort <- matrix(mort, ns + 1L)
  msg <- matrix(rbind(do.call(rbind, lapply(res$msgs, `[[`, 1)), attr(Kend, "msg")[[1]]), ns + 1L)
  fin <- matrix(c(vapply(res$Ys, function(z) apply(is.finite(z[[1]]), 2, all), logical(M)),
                  apply(is.finite(res$Y1[[1]]), 2, all)), nrow = M)
  bad <- t(!is.finite(mort) | (log(birth_rate(1, t_beg[k])) - mort) > 50 | !is.na(msg)) | !fin
  hit <- which(alive & apply(bad, 1, any))
  for (m in hit) {
    s <- which(bad[m, ])[1]
    events[[length(events) + 1L]] <- data.frame(k = k, t0 = t_beg[k], h_days = h * 365, node = INV[[1]]$node[m],
      birth = INV[[1]]$birth[m], stage = s, of = ns + 1L, mort_at_stage = mort[s, m],
      msg = if (is.na(msg[s, m])) "density refused" else msg[s, m], r0 = r0[m], P0 = P[m],
      tau_eff_d = tau_eff[m] * 365, x = x[m],
      min_r = min(vapply(res$Ys, function(z) z[[1]][I_STORE, m], 0) / cap[m]))
    cat(sprintf("t %.6f (step %d, %.2f d): member %d (born %.3f) refused at stage %d of %d: mortality %.3g; r0 %.3g, P0 %.3g, tau_eff %.2f d, h/tau_eff %.2f\n",
                t_beg[k], k, h * 365, INV[[1]]$node[m], INV[[1]]$birth[m], s, ns + 1L, mort[s, m], r0[m], P[m],
                tau_eff[m] * 365, x[m]))
  }
  # A member plant keeps but the step killed: mortality up by more than 1 (a
  # survival factor of e) in one step, which no member's own rates come near.
  dmu <- res$Y1[[1]][I_MORT, ] - y[I_MORT, ]
  for (m in which(alive & !(seq_len(M) %in% hit) & is.finite(dmu) & dmu > 1 & y[I_MORT, ] < 745)) {
    kills[[length(kills) + 1L]] <- data.frame(k = k, t0 = t_beg[k], h_days = h * 365, node = INV[[1]]$node[m],
      birth = INV[[1]]$birth[m], dmu = dmu[m], mort0 = y[I_MORT, m], r0 = r0[m], P0 = P[m],
      tau_eff_d = tau_eff[m] * 365, x = x[m],
      min_r = min(vapply(res$Ys, function(z) z[[1]][I_STORE, m], 0) / cap[m]),
      mort_rate_max = max(vapply(res$Kl, function(z) z[[1]][I_MORT, m], 0)))
  }
  alive[hit] <- FALSE
  Ynew <- res$Y1[[1]]
  Ynew[, !alive] <- Y[[1]][, !alive]  # a dropped member is held where it was, unrated
  Y[[1]] <- Ynew
  if (k %% 2000 == 0) cat(sprintf("step %d t %.3f: %d members, %d dropped, %.0f s\n", k, t_end[k], M, sum(!alive),
                                  proc.time()[["elapsed"]] - t_clock))
}
ev <- if (length(events)) do.call(rbind, events) else NULL
kl <- if (length(kills)) do.call(rbind, kills) else NULL
if (!is.null(kl)) {
  cat("members a step killed (mortality up by more than 1 in one step):\n")
  print(kl, row.names = FALSE, digits = 3)
}
# Each member's offspring at t = 40 against the reference pass, where it holds
# that member.
p1 <- file.path(S, paste0("pass1_", REC, ".rds"))
off <- NULL
if (file.exists(p1)) {
  P1 <- readRDS(p1)
  i_ref <- match(INVADER, P1$invaders)
  ref40 <- P1$saved[[sprintf("%.10f", 40)]][[i_ref]]
  m_ref <- match(INV[[1]]$node, P1$members[[i_ref]]$node)
  ok <- !is.na(m_ref)
  off <- data.frame(node = INV[[1]]$node[ok], walk = Y[[1]][I_OFF, ok], ref = ref40[I_OFF, m_ref[ok]],
                    mort_walk = Y[[1]][I_MORT, ok], mort_ref = ref40[I_MORT, m_ref[ok]])
  off$rel <- off$walk / off$ref - 1
  cat(sprintf("offspring at t = 40 against the reference, %d members: largest |relative error| %.3g (member %d); median %.3g\n",
              nrow(off), max(abs(off$rel)), off$node[which.max(abs(off$rel))], median(abs(off$rel))))
}
saveRDS(list(rec = REC, invader = INVADER, method = METHOD, nodes = INV[[1]]$node, births = INV[[1]]$birth,
             events = ev, kills = kl, worst = worst, alive = alive, final = Y[[1]], offspring = off), OUT)
cat(sprintf("%s walk of %s on %s: %d members refused, %d steps killed a member; largest h/tau_eff met %.2f (t %.3f, %.2f d, member %d, r0 %.3g, P0 %.3g); %.0f s\n",
            METHOD, INVADER, REC, sum(!alive), if (is.null(kl)) 0L else nrow(kl), worst$x, worst$t0, worst$h_days,
            worst$node, worst$r0, worst$P0, proc.time()[["elapsed"]] - t_clock))
