#   Rscript scripts/gradient_budget.R
#
# The forward run a gradient is priced against, and the share of it the transport
# stencil's finite-difference probe holds. Per-call leaf costs are leaf_call_cost.R;
# keeping them there stops one measurement having two homes.
#
# CONFIGURATION. plant develop 141dc8df, odelia 854a8e18, built -O2 -DNDEBUG via
# pkgbuild::compile_dll(debug = FALSE). compile_dll's default appends -UNDEBUG -g -O0
# after any user CXXFLAGS, so the last -O wins and the default build is -O0 whatever
# Makevars asks for. scm_base_parameters("TF24","TF24_Env") with add_strategies(
# trait_matrix(0.1978791,"lma")), Control(), refine_schedule = FALSE, five soil
# layers, one species. max_patch_lifetime is set on the base parameters, before
# add_strategies, because that call builds the node schedule.
#
# RESULTS. The seconds are the machine's; the offspring value and the step count are
# not -- report 01 s2 records the same offspring on a box that runs it in 89.9 s.
#   forward, life 105.32   102.9 s, 103.7 s     offspring 42.14017357509567
#   stencil, life 20       36.92 s with one probe per cohort-stage
#                          53.58 s with four (Richardson depth 2)
#                          5.56 s per marginal probe, 15.0% of the run -- a lower
#                          bound, since the extra probes reuse caches the first fills

suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })
options(digits = 16)

reps <- as.integer(Sys.getenv("REPS", "2"))

run_once <- function(life) {
  p0 <- scm_base_parameters("TF24", "TF24_Env")
  p0$max_patch_lifetime <- life          # before add_strategies: it builds the schedule
  p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
  t0 <- Sys.time()
  r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)
  list(s = as.numeric(Sys.time() - t0, "secs"),
       off = sum(r$offspring_production),
       steps = nrow(r$steps),
       out_times = length(r$time))
}

cat("=== the forward run at production lifetime\n")
h <- lapply(seq_len(reps), function(i) run_once(105.32))
for (i in seq_along(h))
  cat(sprintf("  rep %d  %7.2f s   steps %5d   offspring %.16g\n",
              i, h[[i]]$s, h[[i]]$steps, h[[i]]$off))
best <- h[[which.min(vapply(h, function(x) x$s, 0))]]
cat(sprintf("  best %.2f s over %d output times\n", best$s, best$out_times))
cat(sprintf("  spread across reps %.1f%%\n",
            100 * (max(vapply(h, function(x) x$s, 0)) / best$s - 1)))

cat("\n=== the stencil's share, from its marginal probe cost (life 20)\n")
stencil <- function(rich, depth = 2) {
  p0 <- scm_base_parameters("TF24", "TF24_Env")
  p0$max_patch_lifetime <- 20
  p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
  ctrl <- Control()
  ctrl$node_gradient_richardson <- rich
  if (rich) ctrl$node_gradient_richardson_depth <- depth
  t0 <- Sys.time()
  r <- run_scm(p, Environment("TF24"), ctrl, collect = TRUE, refine_schedule = FALSE)
  list(s = as.numeric(Sys.time() - t0, "secs"), steps = nrow(r$steps))
}
a <- stencil(FALSE)
b <- stencil(TRUE, 2)
cat(sprintf("  1 probe per cohort-stage : %6.2f s  (%d steps)\n", a$s, a$steps))
cat(sprintf("  4 probes (Richardson 2)  : %6.2f s  (%d steps)\n", b$s, b$steps))
cat(sprintf("  marginal cost per probe  : %6.3f s  -> one probe is %.1f%% of the run,\n",
            (b$s - a$s) / 3, 100 * ((b$s - a$s) / 3) / a$s))
cat("     a lower bound: the extra probes reuse caches the first one fills.\n")

