# plant-113 whole game: the synthetic 41-year record's stand (harness/long_drought.R:
# one TF24 species at lma 0.32, 108 uniform introductions over 40 years, birth
# date, ode_tol 1e-3, a zero-depth pulse at every active rain knot), then an
# invader at lma x2 on the resident's steps.
#   PLANT_LIB=<lib> Rscript wholegame-run.R <label>
source("/home/user/plant-dev/harness/long_drought.R")
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/probe/load_probe.R")
load_rejection_probe(Sys.getenv("PLANT_LIB"))
label <- commandArgs(TRUE)[[1]]
cpu <- function(t) sum(t[c("user.self", "sys.self")])
times <- uniform_times(108)
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
p <- stand_at(times)
stops <- events(events_default(p), pulse_rows(AK))
t0 <- proc.time()
scm <- run_scm(p, mkenv(), ctrl, events = stops)
t1 <- proc.time() - t0
cat(sprintf("%s resident: J %.9f accepted %d rejected %.0f cpu %.1f s\n", label,
            sum(scm$offspring_production), length(scm$ode_times) - 1,
            scm_rejections_tf24(scm$.ptr), cpu(t1)))
for (f in c(2, 1.2, 0.9)) {
  t0 <- proc.time()
  r <- tryCatch({
    scm$run_mutant(stand_at(times, "lma", f))
    sprintf("J' %.6g", sum(scm$offspring_production))
  }, error = function(e) paste("Error:", conditionMessage(e)))
  cat(sprintf("%s invader lma x%g: %s (cpu %.1f s)\n", label, f, r,
              cpu(proc.time() - t0)))
}
