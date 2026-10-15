# Jitter of d(step map)/d(theta) across switch positions u in (0,1), against the exact
# derivative: rms over u of (map's derivative - exact), for the plain step and the step
# with the switch's quadrature error subtracted, at several h*a (coupling across the step).
source_lines <- readLines("toy_forward_correction.R"); eval(parse(text = source_lines[1:grep("^d <- 1e-6", source_lines)]))
scan <- function(a_, h_) { a <<- a_; h <<- h_
  us <- seq(0.0123, 0.9877, length.out = 197)  # off the stage fractions, where a central difference straddles a jump
  r <- t(sapply(us, function(u) { th <- y0 - u * h; c(D(rk, th), D(corrected, th), D(exact, th)) }))
  c(ha = a_ * h_, rms_plain = sqrt(mean((r[, 1] - r[, 3])^2)), rms_corr = sqrt(mean((r[, 2] - r[, 3])^2)),
    ratio = sqrt(mean((r[, 2] - r[, 3])^2)) / sqrt(mean((r[, 1] - r[, 3])^2))) }
print(round(t(sapply(list(c(2, .5), c(1, .5), c(.5, .5), c(.2, .5), c(.1, .5), c(2, .1), c(2, .05))
                     , function(p) scan(p[1], p[2]))), 5))
