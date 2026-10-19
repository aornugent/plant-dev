# The test's Newton and invader-at-b* steps, with their numbers printed.
suppressMessages(library(plant))
src <- readLines(file.path(Sys.getenv("TESTS"), "test-tf24-fitness-gradient.R"))
eval(parse(text = src[1:(grep("^test_that", src)[1] - 1)]))
b <- 10; t0 <- proc.time()[[3]]
for (k in 1:8) {
  resident <- fitness_stand_run(fitness_stand_parameters(b))
  g <- stand_gradient(resident, metrics = "1.offspring_production", traits = "1.birth_rate")
  J <- g$value[[1]]; excess <- log(J) - log(b); s <- b * g$gradient[[1]] / J
  cat(sprintf("run %d  b %.10g  ln J - ln b %.2e  d ln J/d ln b %.4f\n", k, b, excess, s))
  if (abs(excess) < 1e-8) break
  b <- exp(log(b) - excess / (s - 1))
}
cat(sprintf("Newton: %.1f s\n", proc.time()[[3]] - t0))
resident$record_trajectory <- TRUE
resident$run_mutant(fitness_stand_parameters(1))
cat(sprintf("identical invader R0' - 1 = %.2e\n", resident$net_reproduction_ratios - 1))
for (m in c(0.9, 1.1)) {
  invader <- fitness_stand_parameters(1, m)
  resident$record_trajectory <- TRUE
  t1 <- proc.time()[[3]]
  resident$run_mutant(invader)
  gi <- stand_gradient(resident, metrics = "1.net_reproduction_ratio", traits = c("1.lma", "1.hmat", "1.k_I"))
  t2 <- proc.time()[[3]]
  resident$record_trajectory <- FALSE
  for (name in c("lma", "hmat", "k_I")) {
    x <- invader$strategies[[1]]$pars[[name]]
    for (rel in c(1e-3, 1e-4)) {
      h <- rel * x
      at <- function(v) { q <- invader; q$strategies[[1]]$pars[[name]] <- v; resident$run_mutant(q); resident$net_reproduction_ratios }
      fd <- (at(x + h) - at(x - h)) / (2 * h)
      sw <- gi$gradient[1, paste0("1.", name)]
      cat(sprintf("x%.1f R0' %.6g %-5s rel %g sweep %.8g fd %.8g err %.1e  (walk+sweep %.1fs)\n", m, gi$value[[1]], name, rel, sw, fd, abs(sw / fd - 1), t2 - t1))
    }
  }
}
