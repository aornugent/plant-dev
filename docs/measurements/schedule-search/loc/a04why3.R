# Three runs share one committed schedule: a04's check (ratio 1.6) and c05_graded's
# (bisection) refine the founders' window and the rest by different amounts. Per quantity,
# fit err = A*shrink_founders + B*shrink_rest to all three; the founders' share A/(A+B)
# says where the error sits, and the residual says whether two groups explain the runs.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); R <- AR; case <- Sys.getenv("CASE", "dry-flat")
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", alg)
cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]))
lf <- approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2); PW <- as.numeric(Sys.getenv("PW", alg$PW))
grp <- function(S, pw) { lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(pw * lf(m)); w[p$shut(m) > 0.5] <- 0; e <- w * (hi - lo)^3
  c(F = sum(e[m < p$b1]), P = sum(e[m >= p$b1])) }
x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
k0 <- intersect(names(x), names(y)); ref <- extrap(x[k0], y[k0])
rd <- function(n) readRDS(file.path(R, sprintf("val_%s_%s.rds", n, case)))
C <- rd("a04t_c"); A <- rd("a04t_f"); B <- rd("c5g_f"); C2 <- rd("c5g_c")
cat(sprintf("committed schedules identical: %s\n", isTRUE(all.equal(C$node_times, C2$node_times))))
for (pw in c(PW, 0)) { g0 <- grp(C$node_times, pw); sa <- grp(A$node_times, pw) / g0; sb <- grp(B$node_times, pw) / g0
  cat(sprintf("\nweight within each group: offspring^%.1f | shrinks a04 (F %.3f, rest %.3f), bisection (F %.3f, rest %.3f)\n", pw, sa["F"], sa["P"], sb["F"], sb["P"]))
  k <- Reduce(intersect, list(names(ref), names(quantities(C)), names(quantities(A)), names(quantities(B)))); e <- eps_vec(k)
  ec <- (quantities(C)[k] - ref[k]) / e; ea <- (quantities(A)[k] - ref[k]) / e; eb <- (quantities(B)[k] - ref[k]) / e
  M <- rbind(c(1, 1), c(sa["F"], sa["P"]), c(sb["F"], sb["P"]))
  out <- t(vapply(seq_along(k), function(i) { f <- qr.solve(M, c(ec[i], ea[i], eb[i])); r <- c(ec[i], ea[i], eb[i]) - M %*% f
    c(err_c = ec[i], founders_share = f[1] / sum(f), resid = sqrt(mean(r^2))) }, numeric(3))); rownames(out) <- k
  big <- abs(ec) > 0.3; print(round(out[big, ][order(-abs(out[big, 1])), ], 3))
  cat(sprintf("median founders' share %.2f (proxy's: %.2f); median resid %.3f\n", median(out[big, 2]), g0["F"] / sum(g0), median(out[big, 3]))) }
