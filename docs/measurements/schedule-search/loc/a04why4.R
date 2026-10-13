# Four runs (a04's pair at 1e-4, c05_graded's at 3e-5), each placed by its own schedule:
# err = alpha*F(S) + beta*P(S), F and P the pilot proxy's h^3 sums before and after b1.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); R <- AR; case <- Sys.getenv("CASE", "dry-flat")
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", alg)
cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]))
lf <- approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2)
grp <- function(S, pw) { lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(pw * lf(m)); w[p$shut(m) > 0.5] <- 0; e <- w * (hi - lo)^3
  c(F = sum(e[m < p$b1]), P = sum(e[m >= p$b1])) }
ref <- if (!is.null(CASES[[case]])) reference(case) else { x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k0 <- intersect(names(x), names(y)); extrap(x[k0], y[k0]) }
runs <- lapply(c("a04t_c", "a04t_f", "c5g_c", "c5g_f"), function(n) readRDS(file.path(R, sprintf("val_%s_%s.rds", n, case))))
k <- Reduce(intersect, c(list(names(ref)), lapply(runs, function(r) names(quantities(r))))); e <- eps_vec(k)
E <- sapply(runs, function(r) (quantities(r)[k] - ref[k]) / e)
for (pw in c(alg$PW, 0)) { G <- t(sapply(runs, function(r) grp(r$node_times, pw))); G <- G / G[1, "P"]
  fit <- t(apply(E, 1, function(v) { f <- qr.solve(G, v); c(F_part = G[1, 1] * f[1], P_part = G[1, 2] * f[2], resid = sqrt(mean((v - G %*% f)^2))) }))
  big <- abs(E[, 1]) > 0.3
  cat(sprintf("\noffspring^%.1f: committed F/P proxy ratio %.2f; four-run fit (err of a04's committed run split by group)\n", pw, G[1, 1] / G[1, 2]))
  print(round(cbind(err_c = E[big, 1], fit[big, ]), 3)[order(-abs(E[big, 1])), ])
  cat(sprintf("median |F part| / (|F|+|P|): %.2f; median resid %.3f\n", median(abs(fit[big, 1]) / (abs(fit[big, 1]) + abs(fit[big, 2]))), median(fit[big, 3]))) }
