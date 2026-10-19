# Invader fitness on the test fixture (TF24, 6 yr, hmat 6, 12 introductions,
# tol 1e-6, resident at birth rate 10): resident's vs own leaf operating points.
suppressMessages(library(plant))
src <- readLines(file.path(Sys.getenv("TESTS"), "test-tf24-fitness-gradient.R"))
eval(parse(text = src[1:(grep("^test_that", src)[1] - 1)]))
cat("plant", as.character(packageVersion("plant")), "odelia", as.character(packageVersion("odelia")), "\n")
t0 <- proc.time()[[3]]
scm <- fitness_stand_run(fitness_stand_parameters(10), record = FALSE)
cat(sprintf("resident R0 %.15g  (%.1fs, %d steps)\n", scm$net_reproduction_ratios, proc.time()[[3]] - t0, length(scm$ode_times)))
res <- scm$net_reproduction_ratios
for (m in c(1, 0.7, 0.9, 1.1, 2)) {
  r <- tryCatch({ scm$run_mutant(fitness_stand_parameters(1, m)); scm$net_reproduction_ratios },
                error = function(e) { cat("  error:", conditionMessage(e), "\n"); NA })
  cat(sprintf("lma x%.1f  R0' %.15g  ln R0' - ln R0 %.3e\n", m, r, log(r) - log(res)))
}
two <- fitness_stand_parameters(1, 1)
q <- fitness_stand_parameters(1, 0.9)
two$strategies <- c(two$strategies, q$strategies)
two$node_schedule_times <- rep(two$node_schedule_times, 2)
r <- tryCatch({ scm$run_mutant(two); scm$net_reproduction_ratios }, error = function(e) conditionMessage(e))
cat("two invaders together (x1, x0.9):", format(r, digits = 15), "\n")
