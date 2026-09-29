# Where J's time error accrues, from a run and a tight reference, each kept by
# harness/ark_prototype.R with OUT and STATES:
# - the J-weighted offspring error at every time both land on, the zero pulses
#   and the introductions, and the intervals between them it grows most in;
# - each Cash-Karp step of those intervals retaken from the reference's state,
#   its true error against its estimate, and whether a member's net production
#   changed sign within it.
#
#   PLANT_LIB=... RUN=ck_u108_1e-4.rds REF=ck_u108_1e-6.rds TOL=1e-4 [TOP=10] \
#     Rscript harness/j_error_trace.R
#
# RUN and REF name the OUT files; their STATES are the same names ending
# _states.rds.
Sys.setenv(METHOD = "ck")
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "ark_prototype.R"))
})
states <- function(f) readRDS(sub("\\.rds$", "_states.rds", f))
run <- readRDS(Sys.getenv("RUN")); Sa <- states(Sys.getenv("RUN"))
ref <- readRDS(Sys.getenv("REF")); Sr <- states(Sys.getenv("REF"))
tol_run <- as.numeric(Sys.getenv("TOL"))

# A member's offspring integral enters J with its final weight: its establishment
# weight times its patch density at birth, S_D and a birth rate of one.
S_D <- p$strategies[[1]]$pars$S_D
weight <- ref$by_node$weight * ref$by_node$patch_density * S_D
offspring <- function(M) 9 * (seq_len(M) - 1) + 7
common <- intersect(ref$st$time, run$st$time)
ir <- match(common, ref$st$time)
ia <- match(common, run$st$time)
E <- vapply(seq_along(common), function(k) {
  M <- (length(Sr[[ir[k]]]) - 10) %/% 9
  o <- offspring(M)
  sum(weight[seq_len(M)] * (Sa[[ia[k]]][o] - Sr[[ir[k]]][o])) / ref$J
}, 0)
a <- run$by_node
b <- ref$by_node
cat(sprintf("J %+.3e against the reference: %+.3e from the offspring integrals, %+.3e from the weights\n",
            run$J / ref$J - 1, sum(weight * (a$fecundity - b$fecundity)) / ref$J,
            sum((a$weight - b$weight) * b$fecundity * b$patch_density * S_D) / ref$J))
marks <- c(5, 10, 12, 15, 20, 25, 30, 40)
cat("the offspring error accrued by t =", marks, ":\n ",
    signif(sapply(marks, function(t) E[max(which(common <= t))]), 3), "\n")

dE <- diff(E)
top <- sort(order(-abs(dE))[seq_len(as.integer(Sys.getenv("TOP", "10")))])
cat(sprintf("the %d largest increments hold %.0f%% of their total magnitude\n", length(top),
            100 * sum(abs(dE[top])) / sum(abs(dE))))
held <- 0L
by_step <- list()
retake <- function(y, t0, t1, tl, h0) {
  ct$ode_tol_rel <<- tl
  ct$ode_tol_abs <<- tl
  sv$t <- t0; sv$y <- y; sv$dydt <- rates(y, t0); sv$P <- production(y); sv$h_last <- h0
  steps$k <- 0L
  steps$states <- list()
  while (sv$t < t1) step(t1)
  list(y = sv$y, st = steps$rows[seq_len(steps$k), , drop = FALSE], S = steps$states)
}
for (q in top) {
  y0 <- Sr[[ir[q]]]
  M <- (length(y0) - 10) %/% 9
  while (held < M) {
    held <- held + 1L
    patch$introduce_new_node(1L, times[held])
  }
  o <- offspring(M)
  leg <- retake(y0, common[q], common[q + 1], tol_run, run$st$h[ia[q] + 1])
  ys <- c(list(y0), leg$S)
  ts <- c(common[q], leg$st[, "time"])
  P <- sapply(seq_along(ys), function(i) { invisible(patch$derivs(ys[[i]], ts[i])); production(ys[[i]]) })
  for (i in seq_len(nrow(leg$st))) {
    tight <- retake(ys[[i]], ts[i], ts[i + 1], 1e-9, 1e-5)$y
    true <- abs(ys[[i + 1]] - tight) / (tol_run * abs(tight) + tol_run)
    by_step[[length(by_step) + 1]] <- data.frame(
      t = ts[i], days = 365 * (ts[i + 1] - ts[i]), estimate = leg$st[i, "er"], true = max(true),
      offspring_error = sum(weight[seq_len(M)] * (ys[[i + 1]][o] - tight[o])) / ref$J,
      sign_changes = sum(sign(P[, i]) != sign(P[, i + 1])))
  }
}
X <- do.call(rbind, by_step)
for (crossing in c(FALSE, TRUE)) {
  s <- (X$sign_changes > 0) == crossing
  cat(sprintf("%s: %d steps, offspring error %+.2e (magnitude %.2e); true error over twice the estimate in %.0f%%, median ratio %.2g\n",
              if (crossing) "across a sign change" else "no sign change", sum(s),
              sum(X$offspring_error[s]), sum(abs(X$offspring_error[s])),
              100 * mean(X$true[s] > 2 * pmax(X$estimate[s], 0.05)),
              median(X$true[s] / pmax(X$estimate[s], 1e-6))))
}
