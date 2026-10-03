# Every invader walk on every program: J', or where it raised; and each
# program's longest step over tau_s = 7 days, the largest h/tau_s any member met
# (every invader walks the stand's steps from the first introduction), which
# bounds h/tau_eff from above since tau_eff >= tau_s.
#
#   Rscript walk_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
f_of <- function(p) file.path(D, p)
invs <- c("lma=0.5", "lma=0.7", "lma=1.4", "lma=2", "hmat=0.5", "hmat=0.7", "hmat=1.4", "hmat=2")
# Each program: its driver OUT (for the steps) and the files holding walks on it.
progs <- list(
  "long-drought" = list(
    unweighted = list(drv = "rej/tied_3e-5_soil1", walks = c("window/full/ld_pin_base", "phase1c/walks/ld_base_inner")),
    "rule A" = list(drv = "window/drv/long-drought_rule", walks = "window/full/ld_pin_rule"),
    "cap 15" = list(drv = "phase1c/drv/long-drought_ruleA_h15", walks = "phase1c/full/ld_h15"),
    "cap 22" = list(drv = "phase1c/drv/long-drought_ruleA_h22", walks = "phase1c/full/ld_h22"),
    "cap 26" = list(drv = "phase1c/drv/long-drought_ruleA_h26", walks = character())),
  "long-wet" = list(
    unweighted = list(drv = "window/drv/long-wet_base", walks = c("window/runs/win_long-wet_u108", "phase1c/walks/wet_base_inner")),
    "rule A" = list(drv = "window/drv/long-wet_rule", walks = "phase1c/full/wet_ruleA"),
    "cap 15" = list(drv = "phase1c/drv/long-wet_ruleA_h15", walks = "phase1c/full/wet_h15"),
    "cap 22" = list(drv = "phase1c/drv/long-wet_ruleA_h22", walks = character()),
    "cap 26" = list(drv = "phase1c/drv/long-wet_ruleA_h26", walks = "phase1c/full/wet_ruleA")),
  episodic = list(
    unweighted = list(drv = "window/drv/episodic_base", walks = c("window/full/epi_pin_base", "phase1c/walks/epi_base_inner")),
    "rule A" = list(drv = "window/drv/episodic_rule", walks = "window/full/epi_pin_rule"),
    "rule B" = list(drv = "window/drv/episodic_ruleB", walks = "window/runs/walks_episodic_ruleB"),
    "cap 15" = list(drv = "phase1c/drv/episodic_ruleA_h15", walks = "phase1c/full/epi_h15"),
    "cap 20" = list(drv = "phase1c/drv/episodic_ruleA_h20", walks = "phase1c/walks/epi_h20"),
    "cap 22" = list(drv = "phase1c/drv/episodic_ruleA_h22", walks = "phase1c/walks/epi_h22"),
    "cap 26" = list(drv = "phase1c/drv/episodic_ruleA_h26", walks = "phase1c/walks/epi_h26")))
# One invader's outcome in a walk file: run_record.R's (invaders, failures) or
# invader_window.R's (invaders with J or error).
outcome <- function(x, k) {
  if (!is.null(x$failures[[k]])) return(sprintf("RAISED t=%s", sub(".*time=([0-9]+[.][0-9]+).*", "\\1", x$failures[[k]])))
  v <- x$invaders[[k]]
  if (is.null(v)) return(NA)
  if (!is.null(v$error)) return(sprintf("RAISED t=%s", sub(".*time=([0-9]+[.][0-9]+).*", "\\1", v$error)))
  sprintf("%.4g", v$J)
}
for (r in names(progs)) {
  cat(sprintf("\n== %s\n", r))
  tab <- matrix("-", length(invs) + 1, length(progs[[r]]), dimnames = list(c("longest h / tau_s", invs), names(progs[[r]])))
  for (p in names(progs[[r]])) {
    g <- progs[[r]][[p]]
    f <- f_of(paste0(g$drv, ".rds"))
    if (file.exists(f)) {
      hd <- max(readRDS(f)$st$h) * 365
      tab[1, p] <- sprintf("%.1f d, %.2f", hd, hd / 7)
    }
    for (w in g$walks) {
      fw <- f_of(paste0(w, ".rds"))
      if (!file.exists(fw)) next
      x <- readRDS(fw)
      for (k in invs) { o <- outcome(x, k); if (!is.na(o)) tab[k, p] <- o }
    }
  }
  print(noquote(tab))
}
