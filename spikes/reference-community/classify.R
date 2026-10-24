# Classify a one-shot root (RUN's state.rds) by central differences on the
# ln-trait scale, step H_STEP:
#   H  held-field invader Hessian: g of invaders at x* +- h e_i in the root's
#      recorded field (run_mutant, then a sweep per invader);
#   J  Jacobian of g along the equilibrium: recordings at x* +- h e_i with ln b
#      on the equilibrium's tangent, ln b* - F_lnb^-1 (F + F_theta dx), whose
#      O(h^2) residual cancels in the central difference.
# Also the root's noise: recordings at ln b* + 1e-6 and at half the tolerance.
#
#   RUN=closed EARLY=8 EVOLVE=lma,rho,hmat,vcmax_25 H_STEP=0.01 Rscript classify.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
RUN <- Sys.getenv("RUN", "closed")
RUN_DIR <- file.path(TMP, "runs", RUN)
H_STEP <- as.numeric(Sys.getenv("H_STEP", "0.01"))
CORES <- as.integer(Sys.getenv("CORES", "8"))
k <- length(EVOLVE)

# The root is the recording of step STEP (default: the last saved).
steps <- sort(list.files(RUN_DIR, "^step_[0-9]+\\.rds$"))
STEP <- Sys.getenv("STEP")
root_file <- if (nzchar(STEP)) sprintf("step_%03d.rds", as.integer(STEP)) else tail(steps, 1)
root_step <- as.integer(sub("step_([0-9]+)\\.rds", "\\1", root_file))
root <- readRDS(file.path(RUN_DIR, root_file))
OUT <- file.path(RUN_DIR, sprintf("classify_h%g_s%d", H_STEP, root_step))
dir.create(OUT, showWarnings = FALSE)
root$g <- drop(root$g)
root$F_theta <- drop(root$F_theta)
root$F_lnb <- root$F_lnb[1, 1]
lnb <- root$lnb
x <- drop(root$x)
cat(sprintf("root: lnb %.6f x %s F %.2e |g| %.3e\n", lnb,
            paste(sprintf("%+.5f", x), collapse = " "), root$F, max(abs(root$g))))

e <- function(i, s) replace(numeric(k), i, s * H_STEP)
jobs <- c(
  lapply(seq_len(k), function(i) list(kind = "H", i = i)),
  unlist(lapply(seq_len(k), function(i) lapply(c(1, -1), function(s)
    list(kind = "J", i = i, s = s))), recursive = FALSE),
  list(list(kind = "null_b"), list(kind = "tol")))

run_job <- function(j) {
  f <- file.path(OUT, if (j$kind == "J") sprintf("J_%d_%+d.rds", j$i, j$s) else
    if (j$kind == "H") sprintf("H_%d.rds", j$i) else paste0(j$kind, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  t0 <- proc.time()[[3]]
  out <- tryCatch({
    if (j$kind == "H") {
      r <- record(lnb, x, scm_out = TRUE)
      inv <- invade(r$scm, rbind(x + e(j$i, 1), x + e(j$i, -1)))
      list(F = r$F, g0 = r$g, inv = inv)
    } else if (j$kind == "J") {
      dx <- e(j$i, j$s)
      lnb_j <- lnb - (root$F + sum(root$F_theta * dx)) / root$F_lnb
      record(lnb_j, x + dx)
    } else if (j$kind == "null_b") {
      record(lnb + 1e-6, x)
    } else {
      TOL <<- TOL / 2
      record(lnb, x)
    }
  }, error = function(err) list(err = conditionMessage(err)))
  out$job <- j
  out$secs <- proc.time()[[3]] - t0
  saveRDS(out, f)
  out
}
res <- mclapply(jobs, run_job, mc.cores = CORES, mc.preschedule = FALSE)
bad <- vapply(res, function(r) !is.null(r$err), TRUE)
if (any(bad)) {
  print(res[bad])
  stop("a job failed")
}

H <- matrix(NA, k, k, dimnames = list(EVOLVE, EVOLVE))
J <- H
d2 <- setNames(numeric(k), EVOLVE)
for (r in res) {
  if (r$job$kind == "H") {
    i <- r$job$i
    H[, i] <- (r$inv$g[1, ] - r$inv$g[2, ]) / (2 * H_STEP)
    d2[i] <- (sum(r$inv$lnR) - 2 * r$F) / H_STEP^2
  }
}
for (i in seq_len(k)) {
  up <- res[[which(vapply(jobs, function(j) j$kind == "J" && j$i == i && j$s == 1, TRUE))]]
  dn <- res[[which(vapply(jobs, function(j) j$kind == "J" && j$i == i && j$s == -1, TRUE))]]
  J[, i] <- (drop(up$g) - drop(dn$g)) / (2 * H_STEP)
}
nb <- res[[which(vapply(jobs, function(j) j$kind == "null_b", TRUE))]]
tl <- res[[which(vapply(jobs, function(j) j$kind == "tol", TRUE))]]
Hs <- (H + t(H)) / 2
Js <- J + t(J)
out <- list(run = RUN, h = H_STEP, lnb = lnb, x = x, traits = traits_at(x),
            F = root$F, g = root$g, H = H, H_sym_eigen = eigen(Hs),
            H_asym = norm(H - t(H), "F") / norm(H + t(H), "F"),
            H_diag_from_lnR = d2, J = J, J_eigen = eigen(J)$values,
            JJt_eigen = eigen(Js), M = J - H,
            noise = list(null_b = list(dF = nb$F - root$F, dg = drop(nb$g) - root$g),
                         tol = list(dF = tl$F - root$F, dg = drop(tl$g) - root$g)),
            J_F = sapply(res[vapply(jobs, function(j) j$kind == "J", TRUE)], `[[`, "F"),
            secs = sapply(res, `[[`, "secs"))
saveRDS(out, file.path(HERE, sprintf("classify_%s_h%g_s%d.rds", RUN, H_STEP, as.integer(root_step))))
print(out[c("H", "H_sym_eigen", "H_asym", "H_diag_from_lnR", "J", "J_eigen",
            "JJt_eigen", "noise", "J_F")])
v <- function(m) {
  ess <- all(eigen(Hs)$values < 0)
  cs <- all(eigen(Js)$values < 0)
  if (cs && ess) "ESS and strongly convergence stable (CSS)" else
    if (cs) "branching point (strongly convergence stable, not ESS)" else
      if (ess) "ESS, not strongly convergence stable" else "repeller"
}
cat("verdict:", v(), "\n")
