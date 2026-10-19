# plant-114: one forward run of the synthetic record's stand (harness/long_drought.R:
# 108 uniform introductions, birth date, ode_tol 1e-3, a stop at every rain
# knot), timed as user + system CPU.  PLANT_LIB=<lib> Rscript forward-run.R <rep> <out.csv>
args <- commandArgs(TRUE)
source("/home/user/plant-dev/harness/long_drought.R")
p <- stand_at(uniform_times(108))
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
ev <- events(events_default(p), pulse_rows(AK)); env <- mkenv()
t0 <- proc.time()
scm <- run_scm(p, env, ctrl, events = ev)
t1 <- proc.time() - t0
row <- data.frame(build = basename(Sys.getenv("PLANT_LIB")), rep = as.integer(args[[1]]),
                  J = sprintf("%.17g", sum(scm$offspring_production)),
                  accepted = length(scm$ode_times) - 1,
                  cpu_s = sum(t1[c("user.self", "sys.self")]), elapsed_s = t1[["elapsed"]])
print(row)
write.table(row, args[[2]], sep = ",", row.names = FALSE, append = file.exists(args[[2]]),
            col.names = !file.exists(args[[2]]))
