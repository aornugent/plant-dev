# Every gradient refusal in the combined runs, and in the phase-1c replays of
# rule A capped (which had gradients): role, how many columns are finite, and
# the refusal message.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
files <- c(file.path(D, "phase1c/combined/full", c("comb_epi.rds", "comb_ld.rds", "comb_wet.rds",
                                                   "comb_ld_2.85e-5.rds", "comb_ld_3.15e-5.rds")),
           file.path(D, "phase1c/full", c("epi_h15.rds", "ld_h15.rds", "wet_h15.rds")),
           file.path(D, "phase1a/plant", c("ck10_3e-5.rds", "ck10_2.85e-5.rds", "ck10_3.15e-5.rds")))
for (f in files) {
  if (!file.exists(f)) next
  x <- readRDS(f)
  for (role in c("stand", "invader")) {
    v <- x[[role]]
    if (is.null(v$elasticity)) { cat(sprintf("%-22s %-7s no gradient\n", basename(f), role)); next }
    cat(sprintf("%-22s %-7s finite %d of %d | value %.8g | refusal: %s\n", basename(f), role,
                sum(is.finite(v$elasticity)), length(v$elasticity), v$value,
                if (is.null(v$refusal) || !any(nzchar(v$refusal))) "none" else substr(paste(v$refusal, collapse = " | "), 1, 300)))
  }
}
