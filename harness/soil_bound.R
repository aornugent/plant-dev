# What removing the soil chain's stability limit could save, from one run that
# harness/v12_steps.R recorded with RECORD=1 and STATES: an upper bound, since
# it assumes no rejected attempt.
#
# Each accepted step is re-taken in R with the solver's Cash-Karp tableau and
# summation order, which reproduces its recorded error ratio exactly. Its ratio
# is then recomputed without the soil layers at h |lambda| >= 0.5 beta, and the
# accumulator each of them feeds. The pools stay in the norm, because they stay
# explicit when the soil is implicit.
#
# Each accepted step gets the local limit a = h max(1, min(5, 0.9 r^(-1/5))): r
# is its recorded ratio where the soil is not stiff and its ratio without the
# stiff layers elsewhere, and a step clipped at an entry takes the larger of its
# own limit and its predecessor's. Each leg between entries is then filled with
# ceil(sum h / a) steps.
#
#   PLANT_LIB=... IN=u108.rds STATES=u108_states.rds Rscript harness/soil_bound.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
run <- readRDS(Sys.getenv("IN"))
S <- readRDS(Sys.getenv("STATES"))
rows <- run$rows; st <- run$st; tol <- run$tol
BETA <- 3.7343596
CK <- list(ah = c(1 / 5, 0.3, 3 / 5, 1, 7 / 8),
           b = list(1 / 5, c(3 / 40, 9 / 40), c(0.3, -0.9, 1.2),
                    c(-11 / 54, 2.5, -70 / 27, 35 / 27),
                    c(1631 / 55296, 175 / 512, 575 / 13824, 44275 / 110592, 253 / 4096)),
           c1 = 37 / 378, c3 = 250 / 621, c4 = 125 / 594, c6 = 512 / 1771,
           ec = c(37 / 378 - 2825 / 27648, 250 / 621 - 18575 / 48384,
                  125 / 594 - 13525 / 55296, -277 / 14336, 512 / 1771 - 0.25))

times <- uniform_times(run$nodes)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
patch <- plant:::Patch("TF24", "TF24_Env")(p, mkenv(), ct)
held <- 0L

theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
env <- mkenv()
st$r_R <- NA_real_; st$r_ns <- NA_real_
for (i in seq_len(nrow(st))) {
  k <- st$row[i]; h <- st$h[i]
  while (held < st$M[i]) { held <- held + 1L; patch$introduce_new_node(1L, times[held]) }
  y0 <- S[[k - 1L]]; t0 <- rows$time[k - 1L]; w <- length(y0)
  kk <- vector("list", 6)
  kk[[1]] <- patch$derivs(y0, t0)
  for (j in 2:6) {
    b <- CK$b[[j - 1]]
    ys <- if (j == 2) y0 + b * h * kk[[1]] else {
      comb <- b[1] * kk[[1]]
      for (m in 2:(j - 1)) comb <- comb + b[m] * kk[[m]]
      y0 + h * comb
    }
    kk[[j]] <- patch$derivs(ys, t0 + CK$ah[j - 1] * h)
  }
  yend <- y0 + h * (CK$c1 * kk[[1]] + CK$c3 * kk[[3]] + CK$c4 * kk[[4]] + CK$c6 * kk[[6]])
  yerr <- h * (CK$ec[1] * kk[[1]] + CK$ec[2] * kk[[3]] + CK$ec[3] * kk[[4]] +
               CK$ec[4] * kk[[5]] + CK$ec[5] * kk[[6]])
  ratio <- abs(yerr) / (tol * abs(yend) + tol)
  st$r_R[i] <- max(ratio)
  th <- y0[w - 9:5]
  lam <- ifelse(th > 0 & th <= theta_s, q * K_sat * (th / theta_s)^q / (th * dz), 0)
  if (th[1] < theta_s) {
    rain <- env$extrinsic_drivers_evaluate_range("rainfall", t0)
    lam[1] <- lam[1] + rain * b_inf * (th[1] / theta_s)^b_inf / (th[1] * dz)
  }
  stiff <- which(h * lam >= 0.5 * BETA)
  out <- (w - 9L):(w - 5L)
  out <- c(out[stiff], if (1L %in% stiff) w - 3L, if (5L %in% stiff) w - 2L)
  st$r_ns[i] <- max(ratio[setdiff(seq_len(w), out)])
}
cat(sprintf("re-taken %d steps; the recorded ratio reproduced at %d\n", nrow(st),
            sum(st$r_R == st$er)))

ins <- which(rows$ins)
st$leg <- findInterval(st$row, ins)
st$clipped <- rows$ins[pmin(st$row + 1L, nrow(rows))] | st$row == max(st$row)
limit <- function(r) pmax(1, pmin(5, 0.9 * pmax(r, 1e-15)^(-1 / 5)))
fill <- function(credit) {
  r <- ifelse(st$x_soil < 0.5, st$er, st$r_ns)
  a <- ifelse(st$x_soil < 0.5 | credit, st$h * limit(r), st$h)
  prev <- c(NA, a[-length(a)])
  same <- c(FALSE, st$leg[-1] == st$leg[-nrow(st)])
  a <- ifelse(st$clipped & same, pmax(a, prev), a)
  steps <- ceiling(tapply(st$h / a, st$leg, sum) - 1e-9)
  held <- tapply(st$M, st$leg, function(m) m[1])
  list(steps = sum(steps), member_evaluations = 6 * sum(steps * held))
}

# Today's cost, with each zero pulse a step target: six evaluations per
# accepted step, six per inaccurate attempt and about 3.35 per throw, and one
# per introduction.
a <- run$attempts
rejected <- (6 * a[["rejected_inaccurate"]] + 3.35 * a[["rejected_thrown"]]) /
  (6 * a[["accepted"]])
intro <- rows$M[ins][diff(c(0L, rows$M[ins])) > 0]
today <- 6 * sum(st$M) * (1 + rejected) + sum(intro)
cat(sprintf("today: %d accepted steps, %.4g member evaluations (%.1f%% of them rejected)\n",
            nrow(st), today, 100 * rejected / (1 + rejected)))
for (credit in c(FALSE, TRUE)) {
  f <- fill(credit)
  kept <- 0.4 * a[["rejected_inaccurate"]] / a[["accepted"]] * f$member_evaluations
  cat(sprintf("%s: %d accepted steps; %.1f%% saved with no rejection, %.1f%% keeping 40%% of the inaccurate ones\n",
              if (credit) "soil stability credit" else "legs filled, no credit", f$steps,
              100 * (1 - (f$member_evaluations + sum(intro)) / today),
              100 * (1 - (f$member_evaluations + sum(intro) + kept) / today)))
}
for (c in c(0.8, 0.5)) {
  more <- sum(pmax(0, ceiling(st$x_soil / c - 1e-9) - 1))
  cat(sprintf("Cash-Karp held at h |lambda_soil| <= %.1f beta: about %.0f%% more accepted steps\n",
              c, 100 * more / nrow(st)))
}
