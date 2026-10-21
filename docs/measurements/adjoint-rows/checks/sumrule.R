# (d) The sum rule on the resident: direct + insertions + trapezium over rows of
# lambda_k . df/dtheta(y_k) against the sweep's gradient.
source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
res <- fixture_run()
metric <- "1.offspring_production"
r <- stand_adjoint_rows(res, metric)
t_terms <- system.time(s <- plant:::adjoint_rows_sum_rule_terms_tf24(res, metric))[["elapsed"]]
rec <- res$store_trajectory()
h <- vapply(rec, `[[`, 1, "step_size")
ins <- r$introduction
n <- length(rec)
trap <- 0; left <- 0
for (k in 2:n) if (!ins[k]) {
  trap <- trap + h[k] / 2 * (s$rate[k - 1, ] + s$rate[k, ])
  left <- left + h[k] * s$rate[k - 1, ]
}
g <- r$gradient
tab <- data.frame(trait = names(g), sweep = unname(g), direct = s$direct,
                  insertion = colSums(s$insertion), trapezium = trap,
                  sum = s$direct + colSums(s$insertion) + trap,
                  sum_left = s$direct + colSums(s$insertion) + left)
tab$rel <- (tab$sum - tab$sweep) / abs(tab$sweep)
tab$rel_left <- (tab$sum_left - tab$sweep) / abs(tab$sweep)
tab <- tab[tab$sweep != 0, ]
tab <- tab[order(-abs(tab$sweep * as.numeric(sapply(tab$trait, function(x)
  res$parameters$strategies[[1]]$pars[[sub("^1\\.", "", x)]] %||% NA)))), ]
options(width = 200)
print(head(tab, 25), digits = 6)
cat(sprintf("terms took %.1f s over %d rows; median |rel| trapezium %.3g, left %.3g\n",
            t_terms, n, median(abs(tab$rel)), median(abs(tab$rel_left))))
saveRDS(list(tab = tab, s = s), file.path(Sys.getenv("CHECKS"), paste0("sumrule-", TOL, ".rds")))
