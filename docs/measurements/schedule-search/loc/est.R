# est.R CASE A B: per quantity, err(A), err(B), and the estimates 4/3 (Q_A - Q_B) for A and (Q_A - Q_B)/3 for B.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
a <- commandArgs(TRUE); case <- a[1]; R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
ref <- reference(case); qa <- quantities(readRDS(file.path(R, paste0(a[2], ".rds")))); qb <- quantities(readRDS(file.path(R, paste0(a[3], ".rds"))))
k <- Reduce(intersect, list(names(ref), names(qa), names(qb))); e <- eps_vec(k)
d <- data.frame(errA = (qa[k] - ref[k]) / e, estA = 4 / 3 * (qa[k] - qb[k]) / e, errB = (qb[k] - ref[k]) / e, estB = (qa[k] - qb[k]) / 3 / e)
for (w in c("A", "B")) { er <- d[[paste0("err", w)]]; es <- d[[paste0("est", w)]]; m <- pmax(abs(er), abs(es)) > 1/3
  ok <- abs(es) >= abs(er) / 2 & abs(es) <= 2 * abs(er) & sign(es) == sign(er)
  cat(sprintf("%s (%s): over 1/3 %d, within x2 signed %d; all quantities: median est/err %.2f, cor %.2f, sign agree %d of %d; max|err - est| %.2f\n",
    w, a[1 + match(w, c("A", "B"))], sum(m), sum(ok[m]), median(es / er), cor(es, er), sum(sign(es) == sign(er)), length(er), max(abs(er - es)))) }
print(round(d[order(-abs(d$errA))[1:12], ], 2))
