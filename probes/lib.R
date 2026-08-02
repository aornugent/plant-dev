# Shared helpers: build a collecting SCM so every recorded step's Patch (and its
# Environment) can be interrogated, and evaluate the candidate compression terms
# on any one of those patches.
suppressMessages(library(plant))

scm_collect <- function(p, envnm, ctrl = Control()) {
  ty <- plant:::extract_RcppR6_template_types(p, "Parameters")
  scm <- do.call(plant:::SCM, ty)(p, Environment(envnm), ctrl)
  scm$collect <- TRUE
  scm$run()
  scm
}

smax_of <- function(s1, h)
  s1$pars$a_st1 * plant:::TF24_strategy_expand_allometry(
    s1, h, rep(0, length(h)), rep(0, length(h)))$mass_sapwood

# A: sub-grid probe at fixed absolute storage (develop)
# B: sub-grid probe at fixed reserve fraction
# C: cohort-grid neighbour difference (the total derivative along the curve)
patch_operators <- function(patch, s1, h0, storage = FALSE, eps = 1e-6) {
  env <- patch$environment
  sp  <- patch$species[[1]]
  nds <- sp$nodes
  n <- length(nds)
  if (n == 0) return(NULL)
  h <- g <- A <- B <- S <- f <- Smax <- ld <- mort <- numeric(n)
  for (i in seq_len(n)) {
    nd <- nds[[i]]; ind <- nd$individual; ind$compute_rates(env)
    h[i] <- ind$state("height"); g[i] <- ind$rate("height")
    mort[i] <- ind$state("mortality"); ld[i] <- nd$log_density
    A[i] <- nd$growth_rate_gradient(env)
    if (storage) {
      S[i] <- ind$state("storage"); f[i] <- ind$rate("storage")
      Smax[i] <- smax_of(s1, h[i])
      hp <- h[i] - eps
      rr <- min(max(S[i], 0) / Smax[i], 1)
      i2 <- nd$individual
      i2$set_state("height", hp)
      i2$set_state("storage", rr * smax_of(s1, hp))
      i2$compute_rates(env)
      B[i] <- (g[i] - i2$rate("height")) / eps
    } else B[i] <- A[i]
  }
  nb <- sp$new_node$individual; nb$compute_rates(env)
  hb <- c(h[-1], h0); gb <- c(g[-1], nb$rate("height"))
  dh <- h - hb
  data.frame(time = patch$time, node = seq_len(n), h, hb, dh, g, gb,
             A, B, C = ifelse(dh > 0, (g - gb) / dh, NA_real_),
             S, f, Smax, log_density = ld, mortality = mort)
}
