# The driver's own dense_of (events/ark_prototype.R), lifted out by parsing and
# run on Lotka-Volterra with a toy attempt() of the same pair: each kind's local
# error at u = 1/2 against an RK4 reference should fall as h^5 (the cubic h^4).
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b"
tab <- new.env(); sys.source(file.path(P, "events/ark436.R"), envir = tab)
ex <- parse(file.path(P, "events/ark_prototype.R"))
grab <- function(name) {
  for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name(name))) return(e)
  stop(name)
}
eval(grab("combine")); eval(grab("quintic_weights")); eval(grab("dense_of"))
fode <- function(t, y) c(y[1] * (1.5 - y[2]), y[2] * (y[1] - 1))
rk4_ref <- function(y0, t1, n = 20000) {
  h <- t1 / n; y <- y0; t <- 0
  for (i in seq_len(n)) {
    k1 <- fode(t, y); k2 <- fode(t + h / 2, y + h / 2 * k1); k3 <- fode(t + h / 2, y + h / 2 * k2)
    k4 <- fode(t + h, y + h * k3); y <- y + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4); t <- t + h
  }
  y
}
for (m in c("dp", "ck")) {
  tb <- if (m == "dp") with(tab, list(A = ADP, b = bDP, d = dDP, c = cDP)) else
    with(tab, list(A = ACK, b = bCK, d = dCK, c = cCK))
  attempt <- function(t, y, k1, h) {
    k <- list(k1)
    for (i in 2:6) k[[i]] <- fode(t + tb$c[i] * h, combine(y, tb$A[i, ], k, h))
    y1 <- combine(y, tb$b, k, h)
    list(y = y1, rates = fode(t + h, y1), k = k)
  }
  y0 <- c(2, 0.5)
  hs <- 2^-(2:6)
  kinds <- c("cubic", "quintic", if (m == "dp") "dp4" else "ck4")
  err <- sapply(kinds, function(kd) sapply(hs, function(h) {
    a <- attempt(0, y0, fode(0, y0), h)
    max(abs(dense_of(0, y0, fode(0, y0), a, h, kd)(0.5) - rk4_ref(y0, h / 2)))
  }))
  sl <- apply(err, 2, function(e) unname(coef(lm(log(e) ~ log(hs)))[2]))
  cat(sprintf("%s: slopes %s; ends exact: %s\n", m, paste(sprintf("%s %.2f", kinds, sl), collapse = ", "),
              paste(sapply(kinds[-2], function(kd) {
                a <- attempt(0, y0, fode(0, y0), 0.1); g <- dense_of(0, y0, fode(0, y0), a, 0.1, kd)
                sprintf("%s %.1e/%.1e", kd, max(abs(g(0) - y0)), max(abs(g(1) - a$y)))
              }), collapse = " ")))
}
