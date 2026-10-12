# Rows of stored lattice runs against node count and summed remaining life.
source("/home/user/plant-dev/harness/schedule/lattice.R")
A <- file.path(DEV, "schedtest/adjmap/runs")
for (case in c("dry", "episodic")) {
  fs <- Sys.glob(file.path(A, sprintf("lat_%s_f*_l*.rds", case)))
  d <- do.call(rbind, lapply(fs, function(f) { x <- readRDS(f); b <- x$node_times
    data.frame(n = length(b), life = sum(39.6 - b), rows = x$stand$rows) }))
  m <- lm(rows ~ n + life, d); print(round(coef(m))); cat(sprintf("R2 %.4f\n", summary(m)$r.squared))
  assign(paste0("m_", case), m, envir = globalenv())
}
saveRDS(list(dry = m_dry, episodic = m_episodic), file.path(DEV, "schedtest/loc/rowsmodel.rds"))
