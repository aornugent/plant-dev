# plant-116: Newton in ln b on ln J - ln b for the fitness stand, its slope
# from the birth-rate column of offspring production J, from b = 10, at one
# ode_tol. Writes one row per run.  PLANT_LIB=<B95> Rscript newton-run.R <tol>
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
source(file.path(here, "fixture.R")); load_plant()
tol <- as.numeric(commandArgs(TRUE)[[1]])
b <- 10; rows <- list()
for (k in 1:10) {
  t0 <- proc.time()
  resident <- fitness_stand_run(fitness_stand_parameters(b), tol)
  g <- stand_gradient(resident, metrics = "1.offspring_production", traits = "1.birth_rate")
  J <- g$value[["1.offspring_production"]]; excess <- log(J) - log(b)
  slope <- b * g$gradient[[1]] / J
  rows[[k]] <- data.frame(tol = tol, run = k, b = b, J = J, excess = excess,
                          dlnJ_dlnb = slope, steps = length(resident$ode_times) - 1,
                          cpu_s = sum((proc.time() - t0)[c("user.self", "sys.self")]))
  cat(sprintf("run %d  b %.10g  ln J - ln b %+.2e  d ln J/d ln b %.4f\n", k, b, excess, slope))
  if (abs(excess) < 1e-10) break
  b <- exp(log(b) - excess / (slope - 1))
}
d <- do.call(rbind, rows)
f <- file.path(here, "newton.csv")
write.table(d, f, sep = ",", row.names = FALSE, append = file.exists(f), col.names = !file.exists(f))
