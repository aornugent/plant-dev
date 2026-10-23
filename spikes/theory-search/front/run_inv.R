# One closed-canopy TF24 stand (spikes/field-dimension-066, CASE closed): a
# resident run, then run_mutant over the first INV_N members of the pool.
# Times each phase; the instrumented build counts and times every leaf solve
# (PLANT_LEAF_STATS) and logs a sample of leaf calls (PLANT_LEAF_LOG).
#
#   PHASE=resident Rscript run.R      resident run only
#   PHASE=invade   INV_N=4 Rscript run.R
#
# The stand: long-wet record, lma 0.32 e^-1 = 0.118, ln b* = 3.595, lifetime
# 40, 108 uniform introductions, invaders on every third.
Sys.setenv(PLANT_LIB = "/home/a/.claude/jobs/9d586e52/rlib-leaf")
Sys.setenv(LIFETIME = Sys.getenv("LIFETIME", "40"))
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/harness/long_drought.R")

# CASE=open: the long-drought stand at lma 0.32, ln b* = 1.539, instead.
CASE <- Sys.getenv("CASE", "closed")
REGIME <- if (CASE == "open") "long-drought" else "long-wet"
LMA_SHIFT <- if (CASE == "open") 0 else -1
PHASE <- Sys.getenv("PHASE", "invade")
INV_N <- as.integer(Sys.getenv("INV_N", "4"))
INV_ROWS <- Sys.getenv("INV_ROWS")  # e.g. "1,5,9": pool rows instead of 1..INV_N
OUT <- Sys.getenv("OUT", "/tmp/front/inv")
LNB <- (if (CASE == "open") 1.539 else 3.595) + as.numeric(Sys.getenv("LNB_SHIFT", "0"))
TOL <- 1e-4
TIMES <- uniform_times(108)
TIMES_INV <- TIMES[seq(1, 108, 3)]
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
TRAIT0 <- local({
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0 * exp(LMA_SHIFT)
  v
})
pool <- local({
  set.seed(20261023)
  n <- 47
  x <- sapply(TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})

ctrl <- control()
ctrl$ode_tol_rel <- TOL
ctrl$ode_tol_abs <- TOL * 1e-4
ctrl$node_density_in_birth_date <- TRUE

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(TRAIT0, TRAITS), birth_rate = exp(LNB))
K1 <- as.numeric(Sys.getenv("FIRST_SPLIT", "0")); if (K1 > 0) TIMES <- sort(c(TIMES, TIMES[2] / K1)); KG <- as.integer(Sys.getenv("GEOM", "0")); if (KG > 0) TIMES <- sort(unique(c(TIMES, TIMES[2] * 2^-(1:KG), TIMES[2] * (1:7) / 8))); p$node_schedule_times <- list(TIMES)
if (Sys.getenv("INV_ALL") == "1") TIMES_INV <- TIMES

rows <- if (nzchar(INV_ROWS)) as.integer(strsplit(INV_ROWS, ",")[[1]]) else seq_len(INV_N)
m <- t(apply(pool[rows, , drop = FALSE], 1, function(x) TRAIT0 * exp(x)))
colnames(m) <- TRAITS
# IDENT_EPS: move the identity invader's vcmax_25 by this relative amount, so
# the instrumented build can tell it from the resident (PLANT_LEAF_KEY) and
# put a table or a scale on its P alone.
IDENT_EPS <- as.numeric(Sys.getenv("IDENT_EPS", "0"))
if (IDENT_EPS != 0) {
  m[1, "vcmax_25"] <- m[1, "vcmax_25"] * (1 + IDENT_EPS)
  Sys.setenv(PLANT_LEAF_KEY = sprintf("%.17g", m[1, "vcmax_25"]))
}
# KEY_INDEX: key the table or scale on this invader (an index into rows).
KEY_INDEX <- as.integer(Sys.getenv("KEY_INDEX", "0"))
if (KEY_INDEX > 0) Sys.setenv(PLANT_LEAF_KEY = sprintf("%.17g", m[KEY_INDEX, "vcmax_25"]))
q <- add_mutant(p, m, birth_rate = rep(1, nrow(m)))
T1 <- as.numeric(Sys.getenv("T1SHIFT", "0")); TI <- TIMES_INV; if (T1 != 0) TI[1] <- T1; q$node_schedule_times <- rep(list(TI), nrow(m))

# PROF=<prefix>: gperftools samples each phase into <prefix>_resident.prof and
# <prefix>_invade.prof (shim built from gprof_shim.c).
PROF <- Sys.getenv("PROF")
prof <- function(tag) if (nzchar(PROF)) {
  .C("prof_stop")
  if (nzchar(tag)) .C("prof_start", paste0(PROF, "_", tag, ".prof"))
}
if (nzchar(PROF)) dyn.load("/home/a/.claude/jobs/9d586e52/tmp/leaf/shim/gprof_shim.so")
prof("resident")
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(REGIME), ctrl, run = FALSE)
scm$collect <- FALSE
scm$run()
t1 <- proc.time()[["elapsed"]]
res <- list(F = log(scm$net_reproduction_ratios), steps = length(scm$ode_times),
            secs_resident = t1 - t0, rows = rows, traits = m)
if (PHASE == "invade") {
  prof("invade")
  scm$run_mutant(q)
  res$lnR <- log(scm$net_reproduction_ratios)
  res$secs_invade <- proc.time()[["elapsed"]] - t1
}
prof("")
res$by_node <- tryCatch(lapply(seq_along(scm$patch$species), function(k) scm$patch$species[[k]]$net_reproduction_ratio_by_node), error = function(e) conditionMessage(e)); res$node_times <- tryCatch(lapply(seq_along(scm$patch$species), function(k) scm$patch$species[[k]]$node_times), error=function(e) NULL); print(res[c("F","steps","secs_resident","secs_invade","lnR")]); str(res$by_node)
saveRDS(res, paste0(OUT, ".rds"))
