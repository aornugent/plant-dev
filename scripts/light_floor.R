suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-develop", quiet=TRUE)})
p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
p$max_patch_lifetime <- 105.32
res <- run_scm(p, Environment("TF24"), Control(), collect=TRUE, refine_schedule=FALSE)
la <- res$env$light_availability
cat("=== the light table\n"); cat("dim", paste(dim(la),collapse="x"), " cols:", paste(names(la),collapse=", "), "\n")
cat(sprintf("rows x cols = %d\n\n", nrow(la)*ncol(la)))

cat("=== what report 07 s1.8 censused: every cell of the table, mixed\n")
mix <- suppressWarnings(as.numeric(unlist(la))); mix <- mix[is.finite(mix)]
cat(sprintf("  n %d   min %.4e   <=1e-4: %d (%.3f%%)   <=1e-3: %.3f%%\n",
            length(mix), min(mix), sum(mix<=1e-4), 100*mean(mix<=1e-4), 100*mean(mix<=1e-3)))
for (cn in names(la)) { v <- suppressWarnings(as.numeric(la[[cn]])); v<-v[is.finite(v)]
  cat(sprintf("    %-22s min %.4e  <=1e-4: %6.3f%%\n", cn, min(v), 100*mean(v<=1e-4))) }

cat("\n=== the census actually wanted: the light column alone\n")
lv <- la$light_availability; lv <- lv[is.finite(lv)]
cat(sprintf("  n %d   min %.6e   max %.6e   <=1e-4: %d (%.4f%%)   <=1e-3: %.4f%%\n",
            length(lv), min(lv), max(lv), sum(lv<=1e-4), 100*mean(lv<=1e-4), 100*mean(lv<=1e-3)))
cat(sprintf("  negative knot values (the undershoot claim): %d\n", sum(lv < 0)))
cat(sprintf("  knots per step: min %d  max %d  mean %.1f\n",
            min(table(la$step)), max(table(la$step)), mean(table(la$step))))
