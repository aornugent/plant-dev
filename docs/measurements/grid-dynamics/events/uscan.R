# The events reply's u-scan (prereg_uscan.txt): H(r), the second difference of
# ln J in ln lma, on the plain replay (rp), the split re-detected on each replay
# (sq) and the split on lma's frozen structure (fq), at 1e-4 and its +-5% nudges,
# against the adaptive reference, in eps for lma's curvature in the resident role.
#   Rscript uscan.R
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
R <- file.path(E, "runs")
EPS <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps <- EPS$eps[EPS$role == "resident" & EPS$trait == "d.1.lma" & EPS$unit == "curvature in lma"]
# The adaptive chords at seed 31, each on its own grid, combined over 1e-2 and
# 3e-2 (docs/assessment.md, step 5).
REF <- -43.7

J_of <- function(tag) {
  f <- file.path(R, paste0(tag, ".log"))
  if (!file.exists(f)) return(NA_real_)
  l <- grep("^J to every digit", readLines(f, warn = FALSE), value = TRUE)
  if (length(l)) as.numeric(sub("^J to every digit ", "", l[1])) else NA_real_
}
clamped_of <- function(tag) {
  f <- file.path(R, paste0(tag, ".log"))
  if (!file.exists(f)) return(NA_integer_)
  l <- grep("of the structure's crossings outside their step", readLines(f, warn = FALSE), value = TRUE)
  if (length(l)) as.integer(sub(".*; ([0-9]+) of the structure's.*", "\\1", l[1])) else NA_integer_
}
# The second difference of ln J in ln theta from J at theta (1 + r), theta (1 - r)
# and theta, as analyze.R's diffs().
H_of <- function(Jp, Jm, J0, r) {
  hp <- log1p(r); hm <- -log1p(-r)
  2 * (log(Jp) / (hp * (hp + hm)) + log(Jm) / (hm * (hp + hm)) - log(J0) / (hp * hm))
}
tag <- function(arm, T, r) if (T == "1e-4") sprintf("%s_lma_%s", arm, r) else sprintf("%s_%s_lma_%s", arm, T, r)
base <- function(arm, T) J_of(if (arm == "rp") paste0("rp_", T) else paste0("spq_", T))

arms <- c(rp = "plain", sq = "split, re-detected", fq = "split, frozen structure")
TOLS <- c("1e-4", "9.5e-5", "1.05e-4")
RS <- c("3e-4", "1e-3", "3e-3", "1e-2", "3e-2")
out <- NULL
for (a in names(arms)) for (T in TOLS) for (r in RS) {
  Jp <- J_of(tag(a, T, r)); Jm <- J_of(tag(a, T, paste0("-", r))); J0 <- base(a, T)
  if (any(is.na(c(Jp, Jm, J0)))) next
  H <- H_of(Jp, Jm, J0, as.numeric(r))
  out <- rbind(out, data.frame(arm = arms[[a]], tol = T, r = as.numeric(r), H = H,
                               from_ref = (H - REF) / eps,
                               clamped = paste(clamped_of(tag(a, T, r)), clamped_of(tag(a, T, paste0("-", r))), sep = "/")))
}
cat(sprintf("eps for lma's curvature (resident) %.3f; eps/3 %.3f; eps/10 %.3f; reference %.1f\n\n",
            eps, eps / 3, eps / 10, REF))
print(format(out, digits = 5), row.names = FALSE)

pick <- function(a, T, r) { x <- out$H[out$arm == arms[[a]] & out$tol == T & out$r == r]; if (length(x)) x else NA }
spread <- function(v) if (all(is.finite(v))) (max(v) - min(v)) / eps else NA
cat("\nP1 (the reply): the re-detected split across r in {3e-3, 1e-2, 3e-2} at 1e-4 moves",
    sprintf("%.3f eps (bar 0.1);", spread(sapply(c(3e-3, 1e-2, 3e-2), function(r) pick("sq", "1e-4", r)))),
    "under the nudges at r = 1e-2 it moves",
    sprintf("%.3f eps (bar 1/3)\n", spread(sapply(TOLS, function(T) pick("sq", T, 1e-2)))))
cat("P2 (the reply): the re-detected split's distance from the reference, in eps, at r = 3e-3, 1e-2, 3e-2:",
    paste(sprintf("%+.3f", (sapply(c(3e-3, 1e-2, 3e-2), function(r) pick("sq", "1e-4", r)) - REF) / eps), collapse = ", "), "\n")
cat("P3 (ours): the plain arm's distance from the reference, in eps, at r = 1e-2 and 3e-2:",
    paste(sprintf("%+.3f", (sapply(c(1e-2, 3e-2), function(r) pick("rp", "1e-4", r)) - REF) / eps), collapse = ", "),
    sprintf("(bar 1/3); under the nudges at r = 1e-2 it moves %.3f eps and at 3e-2 %.3f eps (bar 1/3)\n",
            spread(sapply(TOLS, function(T) pick("rp", T, 1e-2))), spread(sapply(TOLS, function(T) pick("rp", T, 3e-2)))))
cat("P4 (ours): the frozen structure less the re-detected split at 1e-4, in eps, at r = 1e-3, 3e-3, 1e-2, 3e-2:",
    paste(sprintf("%+.3f", sapply(c(1e-3, 3e-3, 1e-2, 3e-2), function(r) pick("fq", "1e-4", r) - pick("sq", "1e-4", r)) / eps), collapse = ", "), "\n")
cat("Passage noise, sqrt(N) x 5e-9 / r^2 with N about 78, 200, 650 and 2000 at r = 1e-3, 3e-3, 1e-2, 3e-2, in eps:",
    paste(sprintf("%.4f", sqrt(c(78, 200, 650, 2000)) * 5e-9 / c(1e-3, 3e-3, 1e-2, 3e-2)^2 / eps), collapse = ", "), "\n")
cat(sprintf("Truncation at r = 3e-2, (0.03/0.245)^2/12 of H: %.3f eps\n", (0.03 / 0.245)^2 / 12 * abs(REF) / eps))
