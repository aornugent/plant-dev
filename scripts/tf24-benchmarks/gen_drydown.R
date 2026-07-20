# Whole-profile drydown scenario for the Stage-1 classifier stress battery.
#
# 4 yr of intermittent moderate rain to establish a stand, then a 12 yr zero-rain
# tail. Intent: dry the WHOLE 5-layer profile (not just the top) so the leaf-
# shutdown surface -- which keys on the wettest accessible layer -- can actually
# be reached. (Probe result 2026-07-20: even this does NOT reach shutdown; the
# stand dies and uptake ceases before the deep reservoir drains, and K(theta)
# drainage collapses at low theta. Kept as the maximal dry-end stress case and as
# evidence for the soil-profile mechanistic investigation.)
build <- rep(c(0, 0, 3, 0, 0, 0, 5, 0), length.out = 4 * 365)
rain  <- c(build, rep(0, 12 * 365))
saveRDS(list(rain = rain, life = length(rain) / 365,
             desc = "4 yr intermittent + 12 yr zero-rain whole-profile drydown"),
        "scripts/tf24-benchmarks/data/drydown.rds")
cat("wrote data/drydown.rds:", length(rain), "days\n")
