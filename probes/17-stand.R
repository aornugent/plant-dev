# Stand structure under each coordinate choice, on the same footing the IBM
# reports it.  Nodes are ordered oldest first, so heights descend while
# introduction times ascend: each integral is taken over its own abscissa in
# ascending order.
source("probes/lib.R"); suppressMessages(library(dplyr))
setwd("/home/user/plant-dev")
p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
ZS <- c(0, 1, 5, 10)

trap <- function(x, y) sum(diff(x) * (head(y,-1) + tail(y,-1)) / 2)

collect_arm <- function(bd) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, "TF24", ct)
  bind_rows(lapply(seq_along(scm$history), function(k) {
    pt <- scm$history[[k]]; sp <- pt$species[[1]]
    if (sp$size < 2) return(NULL)
    dens <- exp(sp$log_densities)          # node order: oldest/tallest first
    hh   <- sp$heights                     # descending
    aa   <- sp$node_times                  # ascending
    stems <- if (bd) trap(aa, dens) else trap(rev(hh), rev(dens))
    nb <- sp$new_node$individual; nb$compute_rates(pt$environment)
    la <- vapply(ZS, function(z) sp$compute_competition(z), 0)
    data.frame(time = pt$time, n = sp$size, stems = stems,
               lai0 = la[1], lai1 = la[2], lai5 = la[3], lai10 = la[4],
               hmax = max(hh), birth_g = nb$rate("height"),
               birth_dens = exp(sp$new_node$log_density))
  }))
}

hh <- collect_arm(FALSE); hh$arm <- "height"
bb <- collect_arm(TRUE);  bb$arm <- "birth-date"
saveRDS(rbind(hh, bb), "probes/out/stand.rds")

cat("=== stems per m2 ===\n")
idx <- vapply(c(5,10,20,30,50,75,100), function(t) which.min(abs(hh$time - t)), 1L)
print(data.frame(time = round(hh$time[idx],1), height = hh$stems[idx],
                 birth_date = bb$stems[idx]), digits = 4, row.names = FALSE)
cat("\n=== leaf area above z ===\n")
print(data.frame(time = round(hh$time[idx],1),
      h_z0 = hh$lai0[idx], b_z0 = bb$lai0[idx],
      h_z1 = hh$lai1[idx], b_z1 = bb$lai1[idx],
      h_z5 = hh$lai5[idx], b_z5 = bb$lai5[idx]), digits = 4, row.names = FALSE)
cat("\n=== birth boundary ===\n")
cat(sprintf("birth g: min=%.4g median=%.4g max=%.4g   times with g<=0: %d of %d\n",
    min(hh$birth_g), median(hh$birth_g), max(hh$birth_g), sum(hh$birth_g<=0), nrow(hh)))
cat(sprintf("newborn density  height arm: median=%.4g max=%.4g   birth-date arm: median=%.4g max=%.4g\n",
    median(hh$birth_dens), max(hh$birth_dens), median(bb$birth_dens), max(bb$birth_dens)))
