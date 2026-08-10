# Are develop's two declared smoothing scales the right size for the quantities
# they smooth? A scale much smaller than the spread of its argument is a hard
# switch wearing a smooth coat -- and its derivative is then a spike, which is
# worse for a gradient than the switch was.
#
#   Ppos = 0.5 (P + sqrt(P^2 + storage_prod_eps^2))     storage_prod_eps = 1e-4
#   G    = logistic( (r - a_st2) / storage_gate_width ) a_st2 = 0.1, width = 0.1
suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })
p0 <- scm_base_parameters("TF24", "TF24_Env"); p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
res <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)
d <- as.data.frame(res$species); d <- d[is.finite(d$net_mass_production_dt), ]
cat(sprintf("records: %d\ncolumns: %s\n\n", nrow(d), paste(names(d), collapse=", ")))

P <- d$net_mass_production_dt; eps <- 1e-4
cat("=== net production P, against storage_prod_eps = 1e-4 ===\n")
print(signif(quantile(abs(P), c(0,.01,.1,.25,.5,.75,.9,1)), 4))
for (k in c(1, 3, 10, 100)) cat(sprintf("|P| < %5.0e * eps : %6d  (%6.3f%%)\n",
  k, sum(abs(P) < k*eps), 100*mean(abs(P) < k*eps)))
cat(sprintf("\nP <= 0: %d (%.2f%%);  P <= -eps: %d (%.2f%%)\n",
  sum(P<=0), 100*mean(P<=0), sum(P <= -eps), 100*mean(P <= -eps)))

if ("storage" %in% names(d)) {
  S <- d$storage
  cat("\n=== storage state ===\n"); print(signif(quantile(S, c(0,.01,.1,.5,.9,1)), 4))
  cat(sprintf("storage <= 0 (the max(S,0) clamp): %d (%.3f%%)\n", sum(S<=0), 100*mean(S<=0)))
} else cat("\nstorage not in collected columns\n")
