# The sort's gates (prereg.txt) from sort.sh's runs.
#   DEV=... Rscript sort.R
O <- file.path(Sys.getenv("DEV"), "node_rule", "sort")
run <- function(name) {
  f <- file.path(O, paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)
}
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
a <- run("s108_sort"); b <- run("s108_walk")
if (!is.null(a) && !is.null(b)) {
  same <- identical(a$stand$J, b$stand$J) && identical(a$stand$times, b$stand$times) &&
    identical(a$stand$sizes, b$stand$sizes)
  cat(sprintf("S1, identity at 108: J %.17g / %.17g, %d / %d steps  %s\n", a$stand$J,
              b$stand$J, length(a$stand$times), length(b$stand$times), verdict(same)))
}
pairs <- lapply(1:2, function(k) list(sort = run(paste0("s429_sort", k)),
                                       walk = run(paste0("s429_walk", k))))
if (all(vapply(pairs, function(p) !is.null(p$sort) && !is.null(p$walk), TRUE))) {
  rel <- pairs[[1]]$sort$stand$J / pairs[[1]]$walk$stand$J - 1
  t <- vapply(pairs, function(p) c(p$sort$phases$stand_run$secs, p$walk$phases$stand_run$secs),
              c(0, 0))
  cat(sprintf("S2, the crossed rung at 429: J %.17g / %.17g (%.1e)  %s\n",
              pairs[[1]]$sort$stand$J, pairs[[1]]$walk$stand$J, rel, verdict(abs(rel) <= 1e-12)))
  cat(sprintf("    forward: sort %s s, walk %s s; sort over walk %.3f  %s\n",
              paste(sprintf("%.1f", t[1, ]), collapse = " "),
              paste(sprintf("%.1f", t[2, ]), collapse = " "), mean(t[1, ] / t[2, ]),
              verdict(all(t[1, ] <= t[2, ]))))
}
