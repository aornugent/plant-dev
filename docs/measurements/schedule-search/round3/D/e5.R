source("ptrace.R")
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
nm <- names(readRDS(paste0(O, "e5_n1g.rds"))$gradient)
a <- read_params(paste0(O, "e5_n1g.log"), nm); b <- read_params(paste0(O, "e5_n2.log"), nm)
saveRDS(list(a = a, b = b), paste0(O, "e5_parsed.rds"))
col <- "1.curv_fact_colim"
fa <- approxfun(a$d$t, a$g[, col], rule = 2); fb <- approxfun(b$d$t, b$g[, col], rule = 2)
tt <- seq(0, 40, by = 0.25)
fin <- tail(b$g[, col], 1)
print(round(data.frame(t = tt, n1g = fa(tt), n2 = fb(tt), rel = (fa(tt) - fb(tt)) / fin), 4)[seq(1, length(tt), 2), ])
# biggest single-step increments in each, in units of the final value
ia <- diff(c(0, a$g[, col])); ib <- diff(c(0, b$g[, col]))
cat("n1g largest steps:\n"); o <- order(-abs(ia))[1:10]; print(cbind(a$d[o, ], inc = ia[o] / fin))
cat("n2 largest steps:\n"); o <- order(-abs(ib))[1:10]; print(cbind(b$d[o, ], inc = ib[o] / fin))
