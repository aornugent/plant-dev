# pair.R HI LO [HI LO ...]: a splice pair's difference (HI - LO) in eps, along
# TF24_cost_scale and over all quantities (rms, the jitter direction's cosine).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
X <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
rd <- function(n) { f <- file.path(O, paste0(n, ".rds")); if (!file.exists(f)) f <- file.path(X, paste0(n, ".rds")); readRDS(f) }
ref <- { a <- quantities(rd("X_J13_dry")); b <- quantities(rd("X_J12_dry")); k <- intersect(names(a), names(b)); (a[k] - b[k]) / eps_vec(k) }
a <- commandArgs(TRUE)
for (i in seq(1, length(a), 2)) { h <- rd(a[i]); l <- rd(a[i + 1]); qh <- quantities(h); ql <- quantities(l); k <- intersect(names(qh), names(ql)); d <- (qh[k] - ql[k]) / eps_vec(k)
  kk <- intersect(k, names(ref))
  cat(sprintf("%s - %s: TF24_cost_scale %+.4f eps; rms %.4f max %.4f (%s); cos with default pair %.2f; ln J %+.2e eps\n", a[i], a[i + 1],
    d[grep("TF24_cost_scale", k)[1]], sqrt(mean(d^2)), max(abs(d)), k[which.max(abs(d))], sum(d[kk] * ref[kk]) / sqrt(sum(d[kk]^2) * sum(ref[kk]^2)),
    (log(h$stand$J) - log(l$stand$J)) / 0.025)) }
