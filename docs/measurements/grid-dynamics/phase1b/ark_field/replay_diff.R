# How far a plain replay of an ARK grid drifts from the grid's own recorded soil
# states: the first step that differs and the largest relative difference, over
# the first STEPS steps.
#   PLANT_LIB=... METHOD=ark TOL=3e-5 ATOL=1e-4 NODES=108 GRID=arkc.rds [STEPS=3000] Rscript harness/replay_diff.R
GRID <- Sys.getenv("GRID")
STEPS <- as.numeric(Sys.getenv("STEPS", "3000"))
source("harness/ark_prototype.R")
program <- readRDS(GRID)$st
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
first <- NA; worst <- 0; ns <- 0
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y); sv$K <- klass(sv$y)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (i in which(program$time > sv$t & program$time <= t_end)) {
    a <- attempt(sv$t, sv$y, sv$dydt, program$h[i])
    rec <- as.numeric(unlist(program[i, paste0("soil_", 1:5)]))
    dif <- max(abs(a$y[soil(a$y)] / rec - 1))
    if (is.na(first) && dif > 0) first <- i
    worst <- max(worst, dif)
    sv$t <- program$time[i]; sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
    ns <- ns + 1
    if (ns >= STEPS) break
  }
  if (ns >= STEPS) break
}
cat(sprintf("replayed %d steps to t = %.4f: first differing step %s (t = %s), largest relative soil difference %.3g\n",
            ns, sv$t, first, if (is.na(first)) "-" else sprintf("%.6f", program$time[first]), worst))
