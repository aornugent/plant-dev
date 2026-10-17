# score_lib.R: scoring for the H5 round. The lib19-class references, eps, M (../common.R),
# E6's pair scoring and C1-C5 (../../round4/AG/lib.R score_pair, ../../round4/F/lib.R crit),
# and the H5 layout (lib.R).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R"))
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
err_of <- function(x, ref) { q <- quantities(x); k <- intersect(names(ref), names(q)); (q[k] - ref[k]) / eps_vec(k) }   # AG's, restored after common.R
ref5 <- function(cs) refq(cs)
mv <- function(x, y) { a <- quantities(x); b <- quantities(y); k <- intersect(names(a), names(b)); (a[k] - b[k]) / eps_vec(k) }
onM <- function(e) { m <- M_unit[names(e)]; m[is.na(m)] <- 0; sum(e * m) }
r2 <- function(x) sqrt(mean(x^2))
top <- function(x, n = 4) { i <- names(x)[order(-abs(x))][1:n]; paste(sprintf("%s %+.2f", i, x[i]), collapse = ", ") }
fmt1 <- function(x) sprintf("rms %.3f | max %.2f | M %+.2f | lnJ %+.3f | root_P50 %+.2f | %s", r2(x), max(abs(x)), onM(x), x["lnJ"], x["root_P50"], top(x))
proj <- function(a, b) sum(a * b) / sum(b^2)
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
HYD <- c("a_l1", "root_P50", "omega", "root_c", "stem_c", "storage_relaxation_offset")
LEAF <- c("a", "curv_fact_elec_trans", "k_I", "jmax_25", "lma", "vcmax_25", "R_d_25")
cls <- function(k) ifelse(k == "lnJ", "lnJ", ifelse(k %in% HYD, "hydraulic", ifelse(k %in% LEAF, "leaf", "other")))
rows_of <- function(x) run_cost(x$stand$rows, TRUE)
steps_of <- function(x) length(x$stand$times)
