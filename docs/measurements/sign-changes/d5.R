# D5 (prereg.txt): the invader's gradient at theta' = theta on a split base, the
# carrying walk's and the walk in pieces' at 1e-4 against the walk in pieces' at
# 1e-5, every entry in units of its eps, floored at 0.01 as OBJECTIVES.md sets.
#   CARRY=... PIECES=... REF=... Rscript d5.R   (run_record.R outputs)
here <- tryCatch(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) ".")
eps <- read.csv(file.path(here, "..", "eps.csv"))
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "invader" & eps$trait == trait & eps$unit != "curvature in lma"]
  if (length(e)) max(e[1], 0.01) else NA
}
invader <- function(arm) readRDS(Sys.getenv(arm))$invader
ref <- invader("REF")
traits <- sub("^1\\.", "", names(ref$elasticity))
e <- vapply(traits, eps_of, 0)
cat(sprintf("reference: J' %.10g; %d entries, %d with an eps\n", ref$J, length(e), sum(!is.na(e))))
report <- function(label, g, against) {
  over <- abs(g - against) / e
  k <- which.max(over)
  cat(sprintf("  %-26s largest %.3f eps (%s), %d over eps/3, %d over eps/6, median %.3f\n",
              label, over[k], traits[k], sum(over > 1 / 3, na.rm = TRUE),
              sum(over > 1 / 6, na.rm = TRUE), median(over, na.rm = TRUE)))
}
carry <- invader("CARRY")
pieces <- invader("PIECES")
cat(sprintf("ln J' against the reference: carrying %.3g, in pieces %.3g\n",
            log(carry$J) - log(ref$J), log(pieces$J) - log(ref$J)))
report("carrying, against 1e-5", carry$elasticity, ref$elasticity)
report("in pieces, against 1e-5", pieces$elasticity, ref$elasticity)
report("in pieces, against carrying", pieces$elasticity, carry$elasticity)
nearer <- abs(pieces$elasticity - ref$elasticity) < abs(carry$elasticity - ref$elasticity)
cat(sprintf("entries the walk in pieces holds nearer the reference: %d of %d\n",
            sum(nearer[!is.na(e)]), sum(!is.na(e))))
cat("JOB DONE d5.R\n")
