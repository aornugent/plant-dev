import sys
p = sys.argv[1]; s = open(p).read()
old = 'cat(sprintf("%s %s: J %.12g, %d steps, %.0f rows, %.0f s\\n", scen, mode, out$stand$J,'
new = '''# SOILREC=1: the soil layers at every recorded state, and the forward clamp tallies.
if (Sys.getenv("SOILREC") == "1") {
  rows <- scm$store_trajectory()
  out$soil <- list(time = vapply(rows, `[[`, 0, "time"),
                   theta = t(vapply(rows, function(r) head(tail(r$state, 10), 5), numeric(5))))
  out$forward_clamps <- tryCatch(setNames(plant:::census_clamp_counts_tf24(scm)[[1]][3:5],
    c("moisture_floor", "potential_ceiling", "positivity")), error = function(e) conditionMessage(e))
  save()
}
''' + old
assert old in s, "anchor missing"
open(p, "w").write(s.replace(old, new, 1))
