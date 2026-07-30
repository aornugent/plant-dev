#   Rscript scripts/descending_heights.R
#
# M8. Is the descending-height invariant ever violated on a production run?
# Species stores nodes in descending height and three consumers rely on it:
# Species::height_max() returns nodes.front().height() rather than a max, the
# transport stencil differences against the neighbour below (dh > 0 assumed), and
# the normalised light coordinate routes every query through height_max. Nothing
# enforces, re-sorts or asserts it, and the NSC storage gate supplies a mechanism
# for crossing: a taller cohort with drawn-down reserves sits at growth ~ 0 while a
# shorter one with full reserves grows. If it breaks, dh goes negative and
# log_density_dt flips sign.
#
# CONFIGURATION. plant develop 141dc8df, odelia 854a8e18, built -O2 -DNDEBUG via
# pkgbuild::compile_dll(debug = FALSE). scm_base_parameters("TF24","TF24_Env") with
# add_strategies(trait_matrix(0.1978791,"lma")), Control(), refine_schedule = FALSE,
# max_patch_lifetime = 105.32 set on the base parameters before add_strategies.
#
# RESULTS. Not yet run: two attempts outran their session. Expect ~10 000 records
# over 142 output times. The number that matters is the count of non-descending
# neighbouring pairs; a nonzero count makes height_max's adjoint and the stencil's
# divisor sign need a guard rather than an invariant.

suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)

d <- r$species[[1]]                      # one flat record per (step, node)
d <- d[order(d$step, d$node), ]
gaps <- unlist(lapply(split(d$height, d$step),
                      function(h) if (length(h) > 1) diff(h) else numeric(0)))

cat(sprintf("records %d   steps %d   neighbouring pairs %d\n",
            nrow(d), length(unique(d$step)), length(gaps)))
cat(sprintf("non-descending (h[i+1] >= h[i]): %d\n", sum(gaps >= 0)))
cat(sprintf("worst gap, max(h[i+1] - h[i]); negative means the order holds: %.6e\n", max(gaps)))
cat(sprintf("min |gap| %.6e   median |gap| %.6e\n", min(abs(gaps)), median(abs(gaps))))
