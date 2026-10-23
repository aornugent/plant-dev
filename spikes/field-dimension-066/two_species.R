# A two-species TF24 resident at its joint demographic equilibrium, and its
# competition matrix A_ij = -dF_i / d ln b_j, F_i = ln R_i, by central
# differences in each ln b_j. Resident runs only.
#
#   SP1="lma=0" SP2="lma=-0.5,hmat=0.3" LNB="1.5,0" REGIME=seasonal Rscript two_species.R
#
# Newton on F(ln b) = 0 with a forward-difference Jacobian, then a central
# difference at the root. Every run is saved under RUN_DIR.
Sys.setenv(PLANT_LIB = "/home/a/.claude/jobs/9d586e52/rlib-d066")
Sys.setenv(LIFETIME = "40")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/harness/long_drought.R")
suppressMessages(library(parallel))

HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/spikes/field-dimension-066"
REGIME <- Sys.getenv("REGIME", "seasonal")
CASE <- Sys.getenv("CASE", paste0("two-", REGIME))
RUN_DIR <- file.path("/home/a/.claude/jobs/9d586e52/tmp/d066/runs", CASE)
dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
TOL <- 1e-4
H_NEWTON <- 0.1
H_A <- as.numeric(Sys.getenv("H_A", "0.1"))
TIMES <- uniform_times(108)
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")

traits_of <- function(s) {
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0
  if (nzchar(s)) for (kv in strsplit(strsplit(s, ",")[[1]], "=")) {
    v[[kv[1]]] <- v[[kv[1]]] * exp(as.numeric(kv[2]))
  }
  v
}
TR <- rbind(traits_of(Sys.getenv("SP1")), traits_of(Sys.getenv("SP2")))
colnames(TR) <- TRAITS

run_at <- function(lnb) {
  f <- file.path(RUN_DIR, sprintf("b_%+.6f_%+.6f.rds", lnb[1], lnb[2]))
  if (file.exists(f)) return(readRDS(f))
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, TR, birth_rate = exp(lnb))
  p$node_schedule_times <- list(TIMES, TIMES)
  ct <- control(); ct$ode_tol_rel <- TOL; ct$ode_tol_abs <- TOL * 1e-4
  ct$node_density_in_birth_date <- TRUE
  t0 <- proc.time()[[3]]
  out <- tryCatch({
    scm <- run_scm(p, mkenv(REGIME), ct, run = FALSE)
    scm$collect <- TRUE
    scm$run()
    h <- scm$history
    ground <- vapply(h, function(x) x$state$env$light_availability[1, 2], 0)
    pd <- vapply(h, function(x) x$state$patch_density, 0)
    list(ok = TRUE, lnb = lnb, F = log(scm$net_reproduction_ratios),
         steps = length(scm$ode_times), ground = sum(ground * pd) / sum(pd))
  }, error = function(e) list(ok = FALSE, lnb = lnb, err = conditionMessage(e)))
  out$secs <- proc.time()[[3]] - t0
  saveRDS(out, f)
  out
}

lnb <- as.numeric(strsplit(Sys.getenv("LNB", "1.5,0"), ",")[[1]])
trace <- list()
# NEWTON=0 skips the root search and takes A at LNB as given.
iters <- if (Sys.getenv("NEWTON", "1") == "1") as.integer(Sys.getenv("ITERS", "8")) else 0
if (iters == 0) {
  r0 <- run_at(lnb)
  trace[[1]] <- list(lnb = lnb, F = r0$F, J = NA, ground = r0$ground)
}
for (it in seq_len(iters)) {
  pts <- list(lnb, lnb + c(H_NEWTON, 0), lnb + c(0, H_NEWTON))
  r <- mclapply(pts, run_at, mc.cores = 3)
  if (!all(vapply(r, function(x) isTRUE(x$ok), TRUE))) stop("a run failed")
  F0 <- r[[1]]$F
  J <- cbind(r[[2]]$F - F0, r[[3]]$F - F0) / H_NEWTON
  step <- -solve(J, F0)
  MAX_STEP <- as.numeric(Sys.getenv("MAX_STEP", "0.5"))
  if (max(abs(step)) > MAX_STEP) step <- step * MAX_STEP / max(abs(step))
  cat(sprintf("it %d  ln b %.4f %.4f  F %.4f %.4f  ground %.3f  step %.3f %.3f\n",
              it, lnb[1], lnb[2], F0[1], F0[2], r[[1]]$ground, step[1], step[2]))
  trace[[it]] <- list(lnb = lnb, F = F0, J = J)
  if (max(abs(F0)) < 0.01) break
  lnb <- lnb + step
}
pts <- list(lnb + c(H_A, 0), lnb - c(H_A, 0), lnb + c(0, H_A), lnb - c(0, H_A))
r <- mclapply(pts, run_at, mc.cores = as.integer(Sys.getenv("CORES", "4")))
A <- -cbind(r[[1]]$F - r[[2]]$F, r[[3]]$F - r[[4]]$F) / (2 * H_A)
As <- (A + t(A)) / 2
out <- list(regime = REGIME, traits = TR, lnb = lnb, F = trace[[length(trace)]]$F,
            trace = trace, A = A, sym_eigen = eigen(As)$values,
            skew_ratio = norm(A - t(A), "F") / norm(A + t(A), "F"),
            J_forward = trace[[length(trace)]]$J, h = H_A)
saveRDS(out, file.path(HERE, sprintf("two_species_%s.rds", CASE)))
out$ground <- run_at(lnb)$ground
print(out[c("lnb", "F", "A", "sym_eigen", "skew_ratio", "ground")])
