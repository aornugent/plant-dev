# The three operators evaluated across the whole run, not just the final state,
# and a census of gap closing: d(dh)/dt = g_i - g_below.  A gap that closes is a
# fold forming -- the point at which a density in height stops existing.
source("probes/lib.R"); suppressMessages(library(dplyr))
setwd("/home/user/plant-dev")

sweep_model <- function(nm, envnm, trait, storage) {
  p  <- add_strategies(scm_base_parameters(nm, paste0(nm, "_Env")), trait)
  s1 <- p$strategies[[1]]
  h0 <- get(paste0(nm, "_Individual"))(s1)$state("height")
  scm <- scm_collect(p, envnm)
  steps <- unique(round(seq(2, length(scm$history), length.out = 30)))
  out <- lapply(steps, function(k)
    patch_operators(scm$history[[k]], s1, h0, storage = storage))
  d <- bind_rows(out); d$model <- nm; d
}

cfg <- list(list("TF24","TF24",trait_matrix(0.1978791,"lma"),TRUE),
            list("FF16","FF16",trait_matrix(0.0825,"lma"),FALSE),
            list("K93","K93",trait_matrix(0.059,"b_0"),FALSE))
all <- list()
for (cc in cfg) {
  t0 <- Sys.time(); d <- do.call(sweep_model, cc); all[[cc[[1]]]] <- d
  cat(sprintf("%s swept: %d node-times, %.0fs\n", cc[[1]], nrow(d),
              as.numeric(difftime(Sys.time(), t0, units="secs")))); flush.console()
}
saveRDS(all, "probes/out/through-run.rds")

cat("\n===== operator agreement, interior nodes, whole run =====\n")
for (nm in names(all)) {
  d <- all[[nm]] |> filter(node < max(node), is.finite(C), is.finite(A), dh > 0)
  cat(sprintf("%-5s n=%-6d cor(C,A)=%+.4f  cor(C,B)=%+.4f  cor(A,B)=%+.4f  sign-disagree(C,A)=%.3f\n",
      nm, nrow(d), cor(d$C,d$A), cor(d$C,d$B), cor(d$A,d$B),
      mean(sign(d$C) != sign(d$A))))
}

cat("\n===== TF24 by patch age =====\n")
d <- all[["TF24"]] |> filter(node < max(node), is.finite(C), is.finite(A), dh > 0)
d$era <- cut(d$time, c(-Inf, 1, 3, 6, 12, 30, Inf))
print(as.data.frame(d |> group_by(era) |> summarise(n=n(),
   corCA = cor(C,A), corCB = cor(C,B), sign_dis = mean(sign(C)!=sign(A)),
   med_A = median(A), med_B = median(B), med_C = median(C),
   .groups="drop")), digits=3)

cat("\n===== gap closing: d(dh)/dt = g_i - g_below =====\n")
for (nm in names(all)) {
  d <- all[[nm]]
  cl <- d$g - d$gb
  low <- d$node == ave(d$node, d$time, FUN = max)
  cat(sprintf("%-5s all pairs: closing=%.4f  |  interior only: closing=%.4f  (n=%d)\n",
      nm, mean(cl < 0), mean(cl[!low] < 0), sum(!low)))
  int <- d[!low & cl[!low] < 0 & d$dh[!low] > 0, ]
  if (nrow(int)) {
    tt <- int$dh / -(int$g - int$gb)      # years until the gap closes
    cat(sprintf("      interior closing pairs: %d   min time-to-fold = %.4g yr   frac < 1 yr = %.3f\n",
                nrow(int), min(tt), mean(tt < 1)))
  }
  cat(sprintf("      non-descending (dh<0) observed: %d\n", sum(d$dh < 0)))
}
