# Reference-free: does the late move (f32: l70 -> l35) at theta0 read the move at a moved trait?
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
q <- function(n) { x <- quantities(readRDS(file.path(A, paste0(n, ".rds")))); x[names(x) != "rooting_depth_max"] }
mv <- function(cs, a, b) { x <- q(sprintf("lat_%s_%s", cs, a)); y <- q(sprintf("lat_%s_%s", cs, b)); k <- intersect(names(x), names(y)); (x[k] - y[k]) / eps_vec(k) }
for (pr in list(c("dry", "dry-p50", "f32_l70", "f32_l35"), c("episodic", "episodic-lma", "f16_l70", "f16_l35"), c("long-drought", "ld-102", "f32_l70", "f64_l70"), c("dry", "dry-p50", "f32_l70", "f64_l70"))) {
  a <- mv(pr[1], pr[3], pr[4]); b <- mv(pr[2], pr[3], pr[4]); k <- intersect(names(a), names(b)); a <- a[k]; b <- b[k]
  big <- pmax(abs(a), abs(b)) > 1/4; ok <- sign(a[big]) == sign(b[big]) & abs(a[big]) <= 2 * abs(b[big]) & abs(b[big]) <= 2 * abs(a[big])
  cat(sprintf("%s vs %s, move %s->%s: cor %.2f, rms diff %.3f eps, max|move| %.2f/%.2f, moves over eps/4 agreeing within x2: %d/%d\n", pr[1], pr[2], pr[3], pr[4], cor(a, b), sqrt(mean((a - b)^2)), max(abs(a)), max(abs(b)), sum(ok), sum(big))) }
