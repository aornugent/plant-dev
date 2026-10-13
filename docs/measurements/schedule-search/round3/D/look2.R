R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
rd <- function(n) readRDS(paste0(R, n, "_long-drought.rds"))
ref <- rd("val_a09s_c")$stand
d <- sapply(c("val_a10bug_c","val_a10n1_c","val_a10s_c"), function(n) {s<-rd(n)$stand; s$gradient - ref$gradient})
print(cor(d))
# ratio of difference vectors
print(summary(d[,3]/d[,2]))
print(summary(d[,1]/d[,2]))
print(head(round(cbind(d, ref=ref$gradient),4)[order(-abs(d[,3])),],20))
