# fd.R: J15, the central-difference elasticity along TF24_cost_scale on A's and B's own
# pinned steps against each run's reverse-mode elasticity, in eps.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
rd <- function(f) if (file.exists(f)) readRDS(f)
A <- readRDS(file.path(POUT, "runs", "P_ins3c_dry.rds")); B <- readRDS(file.path(XR, "X_ins3c_2.85e-4_dry.rds"))
e <- eps_vec("TF24_cost_scale"); q <- "1.TF24_cost_scale"
for (r in list(list("A", A), list("B", B))) { up <- rd(file.path(XR, sprintf("X_fd%s_up_dry.rds", r[[1]]))); dn <- rd(file.path(XR, sprintf("X_fd%s_dn_dry.rds", r[[1]])))
  if (is.null(up) || is.null(dn)) next
  fd <- (log(up$stand$J) - log(dn$stand$J)) / log((1 + 1e-4) / (1 - 1e-4))
  cat(sprintf("%s: reverse-mode %.6f, central difference %.6f, difference %.3f eps\n", r[[1]], r[[2]]$stand$elasticity[[q]], fd, (r[[2]]$stand$elasticity[[q]] - fd) / e)) }
cat(sprintf("A - B reverse-mode: %.3f eps\n", (A$stand$elasticity[[q]] - B$stand$elasticity[[q]]) / e))
