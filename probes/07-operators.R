# The candidate compression terms, evaluated on one patch state.
#   A  sub-grid probe at fixed absolute storage      -- what develop computes
#   B  sub-grid probe at fixed reserve fraction      -- report 11 section 8.1
#   C  cohort-grid neighbour difference              -- the total derivative
#      along the cohort curve, which is what d(log J)/dt is
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")
eps <- 1e-6                     # control$node_gradient_eps, backward

smax_fn <- function(s1, h) {
  al <- plant:::TF24_strategy_expand_allometry(s1, h, rep(0, length(h)), rep(0, length(h)))
  s1$pars$a_st1 * al$mass_sapwood
}

operators <- function(nm, envnm, trait, has_storage) {
  p <- add_strategies(scm_base_parameters(nm, paste0(nm, "_Env")), trait)
  s1 <- p$strategies[[1]]
  scm <- run_scm(p, Environment(envnm), Control(), collect = FALSE, refine_schedule = FALSE)
  env <- scm$patch$environment
  sp  <- scm$patch$species[[1]]
  nds <- sp$nodes
  n   <- length(nds)

  h <- g <- A <- B <- Smax <- Sst <- fst <- numeric(n)
  for (i in seq_len(n)) {
    nd <- nds[[i]]
    ind <- nd$individual
    ind$compute_rates(env)
    h[i] <- ind$state("height"); g[i] <- ind$rate("height")
    A[i] <- nd$growth_rate_gradient(env)
    if (has_storage) {
      Sst[i]  <- ind$state("storage"); fst[i] <- ind$rate("storage")
      Smax[i] <- smax_fn(s1, h[i])
      # hold the reserve fraction, not the absolute pool, while perturbing height
      hp <- h[i] - eps
      rr <- min(max(Sst[i], 0) / Smax[i], 1)
      i2 <- nd$individual
      i2$set_state("height", hp)
      i2$set_state("storage", rr * smax_fn(s1, hp))
      i2$compute_rates(env)
      B[i] <- (g[i] - i2$rate("height")) / eps
    } else B[i] <- A[i]
  }
  h0  <- get(paste0(nm, "_Individual"))(s1)$state("height")
  hb  <- c(h[-1], h0); gb <- c(g[-1], 0)
  gb[n] <- { nb <- sp$new_node$individual; nb$compute_rates(env); nb$rate("height") }
  dh  <- h - hb
  C   <- ifelse(dh > 0, (g - gb) / dh, NA_real_)
  data.frame(node = seq_len(n), h, dh, g, A, B, C,
             S = Sst, f = fst, Smax, model = nm)
}

cfg <- list(
  list("TF24", "TF24", trait_matrix(0.1978791, "lma"), TRUE),
  list("FF16", "FF16", trait_matrix(0.0825,    "lma"), FALSE),
  list("K93",  "K93",  trait_matrix(0.059,     "b_0"), FALSE))

res <- list()
for (cc in cfg) {
  d <- do.call(operators, cc); res[[cc[[1]]]] <- d
  int <- d[-nrow(d), ]; int <- int[is.finite(int$C) & is.finite(int$A), ]
  cat(sprintf("\n=== %s === interior nodes = %d\n", cc[[1]], nrow(int)))
  cat(sprintf("  cor(C, A) = %+.4f    mean |C-A|/|A| = %.3f\n",
              cor(int$C, int$A), mean(abs(int$C - int$A) / pmax(abs(int$A), 1e-12))))
  if (cc[[4]]) cat(sprintf("  cor(C, B) = %+.4f    cor(A, B) = %+.4f\n",
                           cor(int$C, int$B), cor(int$A, int$B)))
  cat(sprintf("  range A: [%+.4g, %+.4g]   range C: [%+.4g, %+.4g]\n",
              min(int$A), max(int$A), min(int$C), max(int$C)))
  cat(sprintf("  sign disagreement C vs A: %.3f\n", mean(sign(int$C) != sign(int$A))))
}
saveRDS(res, "probes/out/operators.rds")

cat("\n=== TF24: is C - A the storage term (1-G) f / (w Smax)? ===\n")
d <- res[["TF24"]]; w <- 0.1
d$G <- 1 / (1 + exp(-(pmin(pmax(d$S,0)/d$Smax,1) - 0.1) / w))
d$pred <- (1 - d$G) * d$f / (w * d$Smax)
k <- is.finite(d$C) & is.finite(d$A) & is.finite(d$pred)
cat(sprintf("  n=%d  cor(C-A, pred) = %+.4f  Spearman = %+.4f\n", sum(k),
            cor((d$C-d$A)[k], d$pred[k]), cor((d$C-d$A)[k], d$pred[k], method="spearman")))
fit <- lm(I(C-A) ~ pred, data = d[k,])
cat(sprintf("  regression slope=%.4f intercept=%.4g R2=%.4f\n",
            coef(fit)[2], coef(fit)[1], summary(fit)$r.squared))
cat(sprintf("  A - B (the reserve-dilution part of the develop probe): median=%+.4g, range [%+.4g, %+.4g]\n",
            median((d$A-d$B)[k]), min((d$A-d$B)[k]), max((d$A-d$B)[k])))
cat(sprintf("  as a fraction of |A|: median %.3f\n",
            median(abs((d$A-d$B)[k]) / pmax(abs(d$A[k]), 1e-12))))
