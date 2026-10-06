# Judge's check (M3): how clustered are sign changes of net production on a record
# other than long drought? Replays a recorded 1e-4 program with an R-level
# Cash-Karp (B's tf24_K.R setup, dense-output part removed) and counts steps where
# any node's net production differs in sign at its ends (and over start, stages, end).
args <- commandArgs(TRUE); SCEN_ARG <- args[1]; PROG <- args[2]; LIFE_ARG <- as.numeric(args[3])
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_rr", .libPaths())); suppressMessages(library(plant))
here <- "/home/user/plant-dev/harness"; source(file.path(here, "long_drought.R"))
tab <- new.env(); sys.source(file.path(here, "ark436.R"), envir = tab)
A <- tab$ACK; bw <- tab$bCK; cc <- tab$cCK
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
times <- uniform_times(108); p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- 1e-4; ct$ode_tol_abs <- 1e-8; ct$node_density_in_birth_date <- TRUE
env <- mkenv(SCEN_ARG)
patch <- plant:::Patch("TF24", "TF24_Env")(p, env, ct)
x <- readRDS(PROG); program <- data.frame(time = x$stand$times[-1], h = x$stand$sizes[-1])
NW <- 8; NE <- 11
nnodes <- function(y) { n <- (length(y) - NE) / NW; stopifnot(n == round(n)); n }
production <- function(y) patch$ode_aux[13 * (seq_len(nnodes(y)) - 1) + 3]
NCLAMP <- 0
ev <- function(y, t) tryCatch(patch$derivs(y, t), error = function(e) {
  pool <- NW * (seq_len(nnodes(y)) - 1) + 6
  if (!any(y[pool] < 0)) return(NULL)
  NCLAMP <<- NCLAMP + 1; y[pool] <- pmax(y[pool], 0)
  tryCatch(patch$derivs(y, t), error = function(e2) NULL) })
combine <- function(y, a, k, h) { nz <- which(a != 0); s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]; y + h * s }
nstep <- 0; ends_steps <- 0; any_steps <- 0; ends_ns <- 0; any_ns <- 0; alive <- 0; per <- integer(0); hx <- numeric(0)
t <- 0; t0 <- proc.time()[3]
for (kk in seq_along(times)) {
  if (times[kk] >= LIFE_ARG) break
  patch$introduce_new_node(1L, times[kk])
  y <- patch$ode_state; k1 <- ev(y, t); P0 <- production(y)
  t_end <- if (kk < length(times)) min(times[kk + 1], LIFE_ARG) else LIFE_ARG
  for (i in which(program$time > t & program$time <= t_end)) {
    h <- program$h[i]; kl <- list(k1); Pst <- matrix(0, length(P0), 6); Pst[, 1] <- P0
    for (s in 2:6) { Y <- combine(y, A[s, ], kl, h); ks <- ev(Y, t + cc[s] * h); if (is.null(ks)) stop("stage raised"); kl[[s]] <- ks; Pst[, s] <- production(Y) }
    y1 <- combine(y, bw, kl, h); f1 <- ev(y1, program$time[i]); if (is.null(f1)) stop("end raised"); P1 <- production(y1)
    e <- sign(P0) != sign(P1); a <- apply(cbind(Pst, P1), 1, function(v) length(unique(sign(v))) > 1)
    nstep <- nstep + 1; alive <- alive + length(P0)
    if (any(e)) { ends_steps <- ends_steps + 1; ends_ns <- ends_ns + sum(e); per <- c(per, sum(e)); hx <- c(hx, h) }
    if (any(a)) { any_steps <- any_steps + 1; any_ns <- any_ns + sum(a) }
    t <- program$time[i]; y <- y1; k1 <- f1; P0 <- P1
  }
}
cat(sprintf("%s: steps %d (mean nodes alive %.1f); clamped evals %d; %.0f s\n", SCEN_ARG, nstep, alive / nstep, NCLAMP, proc.time()[3] - t0))
cat(sprintf("  ends differ: %d steps (%.2f%% of rows) hold %d node steps, %.1f per crossing step (median %g); median h at them %.3f d\n",
            ends_steps, 100 * ends_steps / nstep, ends_ns, ends_ns / max(1, ends_steps), median(per), 365 * median(hx)))
cat(sprintf("  any sign change over start, stages, end: %d steps (%.2f%%), %d node steps\n", any_steps, 100 * any_steps / nstep, any_ns))
cat(sprintf("  halving cost: replays +%.1f%% rows, forward +%.1f%% rows (one discarded attempt each)\n",
            100 * ends_steps / nstep, 200 * ends_steps / nstep))
