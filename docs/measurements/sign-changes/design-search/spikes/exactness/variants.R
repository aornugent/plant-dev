# Variants of the smooth correction's reconstruction of P along the step.
#   q5   quartic through stages 1,3,4,6,5 (c = 0, .3, .6, .875, 1)  [toy.R default]
#   c4   cubic through the weighted stages 1,3,4,6
#   q2   quartic through stages 1,2,3,4,6 (c = 0, .2, .3, .6, .875)
set_variant <- function(v) {
  sel <- switch(v, q5 = c(1, 3, 4, 6, 5), c4 = c(1, 3, 4, 6), q2 = c(1, 2, 3, 4, 6))
  nodes <- cc[sel]
  V <- solve(outer(nodes, 0:(length(nodes) - 1), `^`))
  assign("kink_K", function(Pst) {
    co <- V %*% Pst[sel]
    pe <- function(u) as.vector(outer(u, 0:(length(co) - 1), `^`) %*% co)
    ug <- seq(0, 1, length.out = 129); pg <- pe(ug)
    cuts <- 0
    for (j in which(sign(pg[-1]) != sign(pg[-length(pg)])))
      cuts <- c(cuts, uniroot(pe, ug[c(j, j + 1)], tol = 1e-15)$root)
    cuts <- c(cuts, 1)
    I <- 0
    for (j in seq_len(length(cuts) - 1)) {
      a <- cuts[j]; b <- cuts[j + 1]
      I <- I + (b - a) * sum(GL$w * gfun(pe(a + (b - a) * GL$x)))
    }
    I - sum(bw * gfun(Pst))
  }, envir = globalenv())
}
