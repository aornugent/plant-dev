# root_P50's resident elasticity across every ladder and schedule on disk, against its eps.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
el <- function(f, q = "root_P50") { if (!file.exists(f)) return(NA); x <- readRDS(f)$stand$elasticity; if (is.null(x)) return(NA); unname(x[paste0("1.", q)]) }
eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv"); e <- eps$eps[eps$role == "resident" & eps$trait == "root_P50"][1]; cat("eps root_P50 resident:", e, "\n")
NR <- file.path(D, "node_rule/ladder/runs"); PL <- file.path(D, "schedtest/placement/runs"); Q <- file.path(D, "schedtest/placed2/runs"); A <- file.path(D, "schedtest/adjmap/runs")
for (rec in c("episodic", "dry")) {
  cat("\n==", rec, "\n")
  u <- c(u108 = el(file.path(NR, paste0("u108_", rec, ".rds"))), u215 = el(file.path(NR, paste0("u215_", rec, ".rds"))), u429 = el(file.path(NR, paste0("u429_", rec, ".rds"))), u857 = el(file.path(PL, paste0("u857_", rec, ".rds"))))
  cat("uniform:", paste(sprintf("%s %.4f", names(u), u), collapse = " | "), " moves:", paste(sprintf("%+.4f", diff(u[!is.na(u)])), collapse = " "), "\n")
  m <- c(L0 = el(file.path(Q, paste0("m_th0_", rec, ".rds"))), L1 = el(file.path(Q, paste0("m_th02_", rec, ".rds"))), L2 = el(file.path(Q, paste0("m_th04_", rec, ".rds"))))
  cat("edge ladder:", paste(sprintf("%s %.4f", names(m), m), collapse = " | "), " moves:", paste(sprintf("%+.4f", diff(m)), collapse = " "), "\n")
  for (n in c(sprintf("hier_dy_%s_p%d", rec, 0:1), sprintf("hier_u108e_%s_p%d", rec, 0:1), sprintf("hybl_dy_%s_p0", rec), sprintf("hyblC_dy_%s_p0", rec)))
    cat(sprintf("  %-26s %.4f\n", n, el(file.path(A, paste0(n, ".rds"))))) }
