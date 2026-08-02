# Seasonal stress, which report 13 lists as untested.  Two mechanisms: an annual
# rainfall cycle (TF24's own drought pathway, and the sweep the storage pull
# request used) and an annual light cycle (closer to the stress period in
# Stefaniak et al., where photosynthesis is halted).  Amplitude 1 puts the
# trough at exactly zero.  For each, both coordinate systems, and a census of
# interior cohort crossings -- the condition under which a density in height
# stops existing.
suppressMessages({library(plant); library(dplyr)}); setwd("/home/user/plant-dev")
MPL <- 105.32

build <- function(driver, amp) {
  p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
  env <- Environment("TF24")
  if (amp > 0) {
    t <- seq(0, MPL, length.out = as.integer(ceiling(MPL * 12)))
    base <- if (driver == "rainfall") 1 else 1800
    y <- pmax(base * (1 + amp * sin(2 * pi * t)), 0)
    env$extrinsic_drivers_set_variable(driver, t, y)
  }
  list(p = p, env = env)
}

census <- function(r, h0) {
  s <- r$species |> arrange(time, node) |> group_by(time) |>
    mutate(h_below = c(height[-1], h0), lowest = node == max(node),
           dh = height - h_below) |> ungroup()
  int <- s |> filter(!lowest)
  list(n_pairs = nrow(int), cross = sum(int$dh < 0), min_dh = min(int$dh),
       bnd_cross = sum(s$dh[s$lowest] < 0),
       min_stor = min(s$storage), frac_stor_neg = mean(s$storage < 0))
}

rows <- list()
for (cfg in list(c("rainfall","0"), c("rainfall","0.3"), c("rainfall","0.7"),
                 c("rainfall","1"), c("PPFD","0.7"), c("PPFD","1"))) {
  drv <- cfg[1]; amp <- as.numeric(cfg[2])
  for (bd in c(FALSE, TRUE)) {
    b <- build(drv, amp)
    h0 <- TF24_Individual(b$p$strategies[[1]])$state("height")
    ct <- Control(); ct$node_density_in_birth_date <- bd
    t0 <- Sys.time()
    out <- tryCatch({
      r <- run_scm(b$p, b$env, ct, collect = TRUE, refine_schedule = FALSE)
      c(list(off = r$offspring_production), census(r, h0))
    }, error = function(e) list(off = NA_real_, err = conditionMessage(e)))
    el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
    if (is.null(out$err)) {
      cat(sprintf("%-9s amp=%-4g %-11s offspring=%-11.6g pairs=%-6d cross=%-3d min_dh=%-10.3g bnd_cross=%-3d min_stor=%-10.3g %5.0fs\n",
        drv, amp, if (bd) "birth-date" else "height", out$off, out$n_pairs,
        out$cross, out$min_dh, out$bnd_cross, out$min_stor, el))
      rows[[length(rows)+1]] <- data.frame(driver=drv, amp=amp, birth_date=bd,
        offspring=out$off, n_pairs=out$n_pairs, cross=out$cross,
        min_dh=out$min_dh, bnd_cross=out$bnd_cross, min_stor=out$min_stor, secs=el)
    } else {
      cat(sprintf("%-9s amp=%-4g %-11s FAILED: %s\n", drv, amp,
                  if (bd) "birth-date" else "height", substr(out$err, 1, 90)))
      rows[[length(rows)+1]] <- data.frame(driver=drv, amp=amp, birth_date=bd,
        offspring=NA, n_pairs=NA, cross=NA, min_dh=NA, bnd_cross=NA,
        min_stor=NA, secs=el)
    }
    flush.console()
  }
}
saveRDS(bind_rows(rows), "probes/out/stress.rds")
