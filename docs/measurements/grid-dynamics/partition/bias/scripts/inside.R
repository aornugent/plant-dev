# Inside a span with no shared times: a run's states at its own step ends against
# the tol 1e-7 reference interpolated there (a cubic spline through the
# reference's dense step ends, per component). Node 1's mortality, storage and
# height, and the soil, plus each step's length and error ratio.
#
#   Rscript inside.R run_out.rds run_states.rds t0 t1
args <- commandArgs(TRUE)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref <- readRDS(file.path(D, "ck_u108_1e-7.rds"))
ref_t <- ref$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
o <- readRDS(args[1]); run_t <- o$st$time
run_s <- readRDS(args[2])
t0 <- as.numeric(args[3]); t1 <- as.numeric(args[4])
iu <- which(run_t >= t0 & run_t <= t1)
M <- (length(run_s[[iu[1]]]) - 10) %/% 9
ir <- which(ref_t >= t0 - 0.01 & ref_t <= t1 + 0.01)
ir <- ir[vapply(ir, function(i) length(ref_s[[i]]) == 9 * M + 10, TRUE)]
comp <- c(n1_mort = 2, n1_stor = 6, n1_h = 1, n1_off = 7, n2_stor = 15)
soil_idx <- 9 * M + 1:5
f_ref <- function(idx, tt) splinefun(ref_t[ir], vapply(ir, function(i) ref_s[[i]][idx], 0), method = "fmm")(tt)
tt <- run_t[iu]
res <- data.frame(t = tt, h_days = o$st$h[iu] * 365, ratio = o$st$er[iu])
for (nm in names(comp)) {
  a <- vapply(iu, function(i) run_s[[i]][comp[[nm]]], 0)
  b <- f_ref(comp[[nm]], tt)
  res[[nm]] <- if (nm == "n1_mort") a - b else (a - b) / abs(b)
  if (nm %in% c("n1_mort", "n1_stor")) res[[paste0(nm, "_ref")]] <- b
}
for (l in 1:5) {
  a <- vapply(iu, function(i) run_s[[i]][soil_idx[l]], 0)
  res[[paste0("soil_", l)]] <- (a - f_ref(soil_idx[l], tt)) / f_ref(soil_idx[l], tt)
}
cat(sprintf("%d run steps in [%g, %g]; %d reference steps; M = %d\n", length(iu), t0, t1, length(ir), M))
options(width = 250)
print(signif(res, 3), row.names = FALSE)
