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
e <- setNames(vapply(traits, eps_of, 0), names(ref$elasticity))
cat(sprintf("reference: J' %.10g; %d entries, %d with an eps\n", ref$J, length(e), sum(!is.na(e))))
report <- function(label, g, against) {
  over <- abs(g - against) / e[names(g)]
  k <- which.max(over)
  cat(sprintf("  %-26s largest %.3f eps (%s), %d over eps/3, %d over eps/6, median %.3f\n",
              label, over[k], sub("^1\\.", "", names(g)[k]), sum(over > 1 / 3, na.rm = TRUE),
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
# Post hoc, given both walks at 1e-5 (CARRY_REF, PIECES_REF): whether the two
# approach each other from opposite sides, and where they meet if each error
# falls by the same factor r between the tolerances.
if (nzchar(Sys.getenv("CARRY_REF")) && nzchar(Sys.getenv("PIECES_REF"))) {
  c4 <- carry$elasticity; p4 <- pieces$elasticity
  c5 <- invader("CARRY_REF")$elasticity; p5 <- invader("PIECES_REF")$elasticity
  ok <- !is.na(e) & abs(c4 - p4) > 0
  toward <- ok & sign(c5 - c4) == -sign(p5 - p4) & abs(c5 - p5) < abs(c4 - p4)
  r <- (c5 - p5) / (c4 - p4)
  limit <- (c5 - r * c4) / (1 - r)
  k <- ok & r > 0 & r < 1
  cat(sprintf("post hoc: %d of %d entries approach each other from opposite sides; the gap's\n",
              sum(toward), sum(ok)))
  cat(sprintf("  factor r has median %.3f; where 0 < r < 1 (%d), the extrapolated limit puts\n",
              median(r[ok]), sum(k)))
  report("in pieces at 1e-4", p4[k], limit[k])
  report("carrying at 1e-4", c4[k], limit[k])
}
cat("JOB DONE d5.R\n")
