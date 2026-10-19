# plant-114: one forward run of the synthetic record's stand (harness/long_drought.R:
# N uniform introductions, birth date, ode_tol TOL, a stop at every rain knot),
# timed as user + system CPU.  PLANT_LIB=<lib> N=<n> TOL=<tol> Rscript forward-run.R <rep> <out.csv>
args <- commandArgs(TRUE)
source("/home/user/plant-dev/harness/long_drought.R")
n <- as.integer(Sys.getenv("N", "108")); tol <- as.numeric(Sys.getenv("TOL", "1e-3"))
p <- stand_at(uniform_times(n))
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = tol, ode_tol_abs = tol)
ev <- events(events_default(p), pulse_rows(AK)); env <- mkenv()
t0 <- proc.time()
scm <- run_scm(p, env, ctrl, events = ev)
t1 <- proc.time() - t0
row <- data.frame(build = basename(Sys.getenv("PLANT_LIB")), n = n, tol = tol, rep = as.integer(args[[1]]),
                  J = sprintf("%.17g", sum(scm$offspring_production)),
                  accepted = length(scm$ode_times) - 1,
                  cpu_s = sum(t1[c("user.self", "sys.self")]), elapsed_s = t1[["elapsed"]])
print(row)
write.table(row, args[[2]], sep = ",", row.names = FALSE, append = file.exists(args[[2]]),
            col.names = !file.exists(args[[2]]))
