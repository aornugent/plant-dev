# Rate-evaluation counts for the whole game's two runs (odelia-57 comment 1).
#   cd <odelia checkout at bfa32cf>; R_LIBS=<its build> Rscript <this file>
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "toy_module.R"))
for (share in c(-1, 0.1)) {
  r <- counted_run(share, 1e-6, 2, store_pars, store_y)
  cat(if (share < 0) "plain" else "substepped", "steps", r$steps,
      "whole System", r$full, "store alone", r$sub, "\n")
}
