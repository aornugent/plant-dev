# Step 2's gates (prereg.txt) from run.sh's runs in R.
#   R=... Rscript analyze.R
R <- Sys.getenv("R")
EPS <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps <- EPS$eps[EPS$role == "resident" & EPS$trait == "d.1.lma" & EPS$unit == "curvature in lma"]
run <- function(tag) {
  f <- file.path(R, paste0(tag, ".rds"))
  if (!file.exists(f)) return(NULL)
  o <- readRDS(f)
  if (is.null(o$stand)) return(NULL)
  list(J = o$stand$J, steps = length(o$stand$times), splits = o$stand$splits,
       secs = o$phases$stand_run$secs, attempts = o$stand$attempts)
}
J_of <- function(tag) { r <- run(tag); if (is.null(r)) NA_real_ else r$J }

ref <- J_of("split_1e-7")
cat(sprintf("J_ref (split, 1e-7) %.10f; plain at 1e-7 %.10f; split at 1e-6 %.10f\n",
            ref, J_of("plain_1e-7"), J_of("split_1e-6")))
cat(sprintf("P2: plain less split at 1e-7, relative %+.2e (bar 1e-6); split 1e-6 less 1e-7 %+.2e (bar 1e-7)\n\n",
            (J_of("plain_1e-7") - ref) / ref, (J_of("split_1e-6") - ref) / ref))

TOLS <- c("1e-3", "3e-4", "1e-4", "3e-5", "1e-5")
tab <- do.call(rbind, lapply(TOLS, function(t) {
  p <- run(paste0("plain_", t)); s <- run(paste0("split_", t))
  if (is.null(p) || is.null(s)) return(NULL)
  data.frame(tol = t, plain_err = (p$J - ref) / ref, split_err = (s$J - ref) / ref,
             plain_steps = p$steps, split_steps = s$steps, splits = s$splits,
             secs_ratio_loaded = s$secs / p$secs)
}))
print(format(tab, digits = 3), row.names = FALSE)
fall <- abs(tab$split_err)
cat(sprintf("\nP1: the split's error falls at every rung: %s (factors %s); at 1e-4 split %.2e, plain %.2e\n",
            all(diff(fall) < 0), paste(sprintf("%.2f", fall[-length(fall)] / fall[-1]), collapse = ", "),
            abs(tab$split_err[tab$tol == "1e-4"]), abs(tab$plain_err[tab$tol == "1e-4"])))
cat(sprintf("    the plain arm's error falls at every rung: %s (factors %s)\n",
            all(diff(abs(tab$plain_err)) < 0),
            paste(sprintf("%.2f", abs(tab$plain_err)[-nrow(tab)] / abs(tab$plain_err)[-1]), collapse = ", ")))

cost <- sapply(c("plain", "split", "plain_1e-5"), function(a) sapply(1:2, function(k) {
  r <- run(sprintf("cost_%s_%d", a, k)); if (is.null(r)) NA else r$secs }))
if (all(is.finite(cost))) {
  cat(sprintf("\nP3: the forward at 1e-4 alone on the machine: plain %s s, split %s s; split / plain %.3f (bar 1.06)\n",
              paste(sprintf("%.1f", cost[, "plain"]), collapse = ", "),
              paste(sprintf("%.1f", cost[, "split"]), collapse = ", "),
              median(cost[, "split"]) / median(cost[, "plain"])))
  s <- run("split_1e-4")
  cat(sprintf("    the split's added seconds per node step split: %.2f ms\n",
              1e3 * (median(cost[, "split"]) - median(cost[, "plain"])) / s$splits))
  cat(sprintf("Extension: plain at 1e-5 alone %s s; the split at 1e-4 over it %.3f\n",
              paste(sprintf("%.1f", cost[, "plain_1e-5"]), collapse = ", "),
              median(cost[, "split"]) / median(cost[, "plain_1e-5"])))
}

# run.sh cost-loose: the slowdown the loaded ladder showed at 1e-3 and 3e-4,
# timed alone, beside the 1e-4 pair above.
loose <- do.call(rbind, lapply(c("1e-3", "3e-4", "1e-4"), function(t) {
  tag <- function(a, k) if (t == "1e-4") sprintf("cost_%s_%d", a, k) else sprintf("cost_%s_%s_%d", a, t, k)
  p <- sapply(1:2, function(k) { r <- run(tag("plain", k)); if (is.null(r)) NA else r$secs })
  s <- sapply(1:2, function(k) { r <- run(tag("split", k)); if (is.null(r)) NA else r$secs })
  n <- run(tag("split", 1))$splits
  data.frame(tol = t, plain_s = median(p), split_s = median(s), ratio = median(s) / median(p),
             splits = n, ms_per_split = 1e3 * (median(s) - median(p)) / n)
}))
if (all(is.finite(loose$ratio))) {
  cat("\nAlone on the machine, each the median of two (cost-loose; 1e-4 from cost):\n")
  print(format(loose, digits = 3), row.names = FALSE)
}

# The second difference of ln J in ln lma about lma, as uscan.R's.
H_of <- function(Jp, Jm, J0, r) {
  hp <- log1p(r); hm <- -log1p(-r)
  2 * (log(Jp) / (hp * (hp + hm)) + log(Jm) / (hm * (hp + hm)) - log(J0) / (hp * hm))
}
RS <- c("1e-3", "1e-2", "3e-2")
H_set <- function(plain, split) sapply(c(plain = plain, split = split), function(arm) {
  base <- if (arm == plain) "plain_1e-4" else "split_1e-4"
  sapply(RS, function(r) H_of(J_of(sprintf("%s_lma_%s", arm, r)), J_of(sprintf("%s_lma_-%s", arm, r)),
                              J_of(base), as.numeric(r)))
})
H <- H_set("rp", "rs")
colnames(H) <- c("rp", "rs")
if (any(is.finite(H))) {
  cat(sprintf("\nH(r) at r = %s, eps for lma's curvature %.3f\n", paste(RS, collapse = ", "), eps))
  print(round(H, 3))
  cat(sprintf("the split's own replay at lma repeats its forward: %s\n",
              identical(J_of("rs_lma_0"), J_of("split_1e-4"))))
  cat(sprintf("P4: split H at 1e-2 and 3e-2 differ by %.3f eps (bar 0.1); from -43.45 by %+.3f and %+.3f eps (bar 1/3)\n",
              abs(H["1e-2", "rs"] - H["3e-2", "rs"]) / eps,
              (H["1e-2", "rs"] + 43.45) / eps, (H["3e-2", "rs"] + 43.45) / eps))
  cat(sprintf("P5: H at 1e-3 less H at 1e-2, in eps: split %+.3f, plain %+.3f (bar 1/3)\n",
              (H["1e-3", "rs"] - H["1e-2", "rs"]) / eps, (H["1e-3", "rp"] - H["1e-2", "rp"]) / eps))
}
Ht <- H_set("tp", "ts")
if (any(is.finite(Ht))) {
  cat("\nNot pre-registered: H(r) with the trait lma moved through the hyperparameterisation\n")
  print(round(Ht, 3))
  cat(sprintf("split: 1e-3 less 1e-2 %+.3f eps, 1e-2 less 3e-2 %+.3f eps; plain: %+.3f and %+.3f eps\n",
              (Ht["1e-3", "split"] - Ht["1e-2", "split"]) / eps, (Ht["1e-2", "split"] - Ht["3e-2", "split"]) / eps,
              (Ht["1e-3", "plain"] - Ht["1e-2", "plain"]) / eps, (Ht["1e-2", "plain"] - Ht["3e-2", "plain"]) / eps))
}

# The passage hypothesis (prereg.txt, second extension): the probe's own forward
# and replays.
Hd <- sapply(RS, function(r) H_of(J_of(sprintf("diff_lma_%s", r)), J_of(sprintf("diff_lma_-%s", r)),
                                  J_of("diff_1e-4"), as.numeric(r)))
if (any(is.finite(Hd))) {
  cat("\nThe probe (the step's own end corrected by what the cuts change):\n")
  print(round(Hd, 3))
  cat(sprintf("P6: its H at 1e-3 less at 1e-2 %+.3f eps (bar 0.1)\n", (Hd["1e-3"] - Hd["1e-2"]) / eps))
  cat(sprintf("P7: its H from -43.45 at 1e-2 and 3e-2 %+.3f and %+.3f eps (bar 1/3); J at 1e-4 from J_ref %+.2e, the split's %+.2e\n",
              (Hd["1e-2"] + 43.45) / eps, (Hd["3e-2"] + 43.45) / eps,
              (J_of("diff_1e-4") - ref) / ref, (J_of("split_1e-4") - ref) / ref))
  d <- run("diff_1e-4"); s <- run("split_1e-4")
  cat(sprintf("    its forward: %d steps, %s splits, %.0f s (the split's %d, %s, %.0f s; both under load)\n",
              d$steps, format(d$splits), d$secs, s$steps, format(s$splits), s$secs))
}
