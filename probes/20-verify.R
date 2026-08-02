# Adversarial checks on report 13's claims.
source("probes/lib.R"); suppressMessages(library(dplyr))
setwd("/home/user/plant-dev")
p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]

cat("=== 1. global max log_density, both arms (not just the newborn) ===\n")
h <- readRDS("probes/out/baseline-TF24.rds")$species
cat(sprintf("height arm:     max log_density = %+.4f  min = %.4g  (n rows %d)\n",
            max(h$log_density[is.finite(h$log_density)]),
            min(h$log_density[is.finite(h$log_density)]), nrow(h)))
ct <- Control(); ct$node_density_in_birth_date <- TRUE
scm <- scm_collect(p, "TF24", ct)
ld <- unlist(lapply(seq_along(scm$history), function(k) scm$history[[k]]$species[[1]]$log_densities))
ld <- ld[is.finite(ld)]
cat(sprintf("birth-date arm: max log_density = %+.4f  min = %.4g  (n %d)\n", max(ld), min(ld), length(ld)))
cat(sprintf("log(birth_rate * max pr_estab) bound = %+.4f\n", max(ld)))

cat("\n=== 2. reserve-fraction difference between neighbours, window t in 1.5-3 ===\n")
w <- readRDS("probes/out/window-TF24.rds")
i <- w |> filter(node < max(node), is.finite(C), dh > 0, time > 1.5, time < 3)
i$r <- pmin(pmax(i$S,0)/i$Smax, 1)
i2 <- i |> arrange(time, node) |> group_by(time) |> mutate(rb = lead(r)) |> ungroup() |> filter(!is.na(rb))
d <- abs(i2$r - i2$rb)
cat(sprintf("n=%d  median=%.3e  75%%=%.3e  90%%=%.3e  99%%=%.3e  max=%.3e\n",
            length(d), median(d), quantile(d,.75), quantile(d,.9), quantile(d,.99), max(d)))

cat("\n=== 3. is the height growth rate ever negative? ===\n")
tr <- readRDS("probes/out/through-run.rds")
for (nm in names(tr)) cat(sprintf("  %-5s min g over sweep = %+.4g   n = %d   any < 0: %s\n",
    nm, min(tr[[nm]]$g), nrow(tr[[nm]]), any(tr[[nm]]$g < 0)))
cat(sprintf("  window sweep min g = %+.4g  (n=%d)\n", min(w$g), nrow(w)))

cat("\n=== 4. convergence of the two coordinates towards each other ===\n")
rf <- readRDS("probes/out/refine.rds")
for (m in c("K93","FF16","TF24")) {
  s <- rf[rf$model==m,]
  for (L in 0:2) {
    a <- s$offspring[s$level==L & !s$birth_date]; b <- s$offspring[s$level==L & s$birth_date]
    cat(sprintf("  %-5s level %d  height=%-12.7g birth=%-12.7g  relative gap=%.3e\n",
                m, L, a, b, abs(b-a)/abs(a)))
  }
}
