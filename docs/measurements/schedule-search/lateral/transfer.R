# Does a schedule's error at theta0 (episodic) read its error at lma x1.25 (episodic-lma)?
# Same lattice rule, each case's own edges and reference. Errors in eps.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
X <- c("rooting_depth_max")
errs <- function(case, pt) { x <- readRDS(file.path(A, sprintf("lat_%s_%s.rds", case, pt))); r <- reference(case); q <- quantities(x)
  k <- setdiff(intersect(names(r), names(q)), X); (q[k] - r[k]) / eps_vec(k) }
for (pt in c("f8_l70", "f16_l140", "f16_l70", "f16_l35", "f32_l70", "f64_l70")) {
  a <- errs("episodic", pt); b <- errs("episodic-lma", pt); k <- intersect(names(a), names(b)); a <- a[k]; b <- b[k]
  big <- pmax(abs(a), abs(b)) > 1/3; ok <- abs(a[big]) >= abs(b[big]) / 2 & abs(a[big]) <= 2 * abs(b[big]) & sign(a[big]) == sign(b[big])
  cat(sprintf("%-8s cor %.2f  rms diff %.2f eps  max|err| epi %.2f lma %.2f  over eps/3: %d, transfer within x2 w/ sign: %d\n", pt, cor(a, b), sqrt(mean((a-b)^2)), max(abs(a)), max(abs(b)), sum(big), sum(ok)))
  if (pt == "f16_l70") { o <- order(-abs(b))[1:6]; print(round(rbind(epi = a[o], lma = b[o]), 2)) } }
# Same test for the move between two nested lattice points (the check's estimate):
mv <- function(case) errs(case, "f16_l70") - errs(case, "f16_l35")
a <- mv("episodic"); b <- mv("episodic-lma"); k <- intersect(names(a), names(b))
cat(sprintf("move (16,70)->(16,35): cor %.2f, rms diff %.2f eps, max|move| %.2f / %.2f\n", cor(a[k], b[k]), sqrt(mean((a[k]-b[k])^2)), max(abs(a[k])), max(abs(b[k]))))
