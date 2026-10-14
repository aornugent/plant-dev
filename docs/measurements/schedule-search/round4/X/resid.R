# resid.R: per gate on dry, the part of a09's committed error that halving every interval
# cannot reach at second order: err_c + (move to the halving)/(1 - 1/4), every quantity.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { for (d in c(XR, AGR, R)) { f <- file.path(d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
for (g in c("AG", "19")) { c0 <- if (g == "AG") ld("AG_a09c_dry") else rd_run("a09", "c", "dry"); nb <- ld(if (g == "AG") "AG_a09nb_dry" else "X_a09nb_dry"); nq <- ld(if (g == "AG") "AG_a09nq_dry" else "X_a09nq_dry")
  if (is.null(nb) || is.null(nb$stand$elasticity)) { cat(g, ": halving missing\n"); next }
  ref <- if (g == "AG") ref_ag("dry") else refq("dry"); k <- Reduce(intersect, list(names(ref), names(quantities(c0)), names(quantities(nb)))); e <- eps_vec(k)
  ec <- (quantities(c0)[k] - ref[k]) / e; eb <- (quantities(nb)[k] - ref[k]) / e; res <- ec - (ec - eb) / 0.75
  cat(sprintf("%s: committed rms %.3f max %.2f | halving rms %.3f | unreached at 2nd order rms %.3f max %.2f (%s) | shrink rms %.2f\n", g, sqrt(mean(ec^2)), max(abs(ec)),
    sqrt(mean(eb^2)), sqrt(mean(res^2)), max(abs(res)), k[which.max(abs(res))], sqrt(mean(ec^2)) / sqrt(mean(eb^2))))
  if (!is.null(nq) && !is.null(nq$stand$elasticity)) { eq <- (quantities(nq)[k] - ref[k]) / e
    cat(sprintf("   quartered rms %.3f max %.2f; predicted at 2nd order from c and the halving: rms of (actual - predicted) %.3f; the three-run limit (2nd order) rms %.3f\n",
      sqrt(mean(eq^2)), max(abs(eq)), sqrt(mean((eq - (res + (eb - res) / 4))^2)), sqrt(mean((eq - (eb - eq) / 3)^2)))) }
  o <- order(-abs(res))[1:8]; print(round(data.frame(err_c = ec[o], err_half = eb[o], unreached = res[o], row.names = k[o]), 2)) }
