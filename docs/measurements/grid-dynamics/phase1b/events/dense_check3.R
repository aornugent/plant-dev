# Where the dense outputs' field errors sit on a grid's crossing steps: as
# dense_check2.R, but each non-crossing member is classed as kinked within the
# step (its net production changes sign at a stage, or its leaf class at the
# step's end differs from the start's) or smooth, and the error is maximised
# over the soil, the kinked members and the smooth members separately.
#   PLANT_LIB=... METHOD=ck TOL=1e-4 GRID=run.rds OUT=dc.rds Rscript harness/dense_check3.R
GRID <- Sys.getenv("GRID")
OUTF <- Sys.getenv("OUT")
Sys.setenv(TF24_DOMAIN_TOL = "1e9")
source("harness/ark_prototype.R")
kinds <- c("cubic", "quintic", if (method == "dp") "dp4" else "ck4")
program <- readRDS(GRID)$st
level_of <- function(y, dydt, h) ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) + ct$ode_tol_abs
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
rows <- list()
mx <- function(e, i) if (length(i)) max(e[i]) else 0
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y); sv$K <- klass(sv$y)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (i in which(program$time > sv$t & program$time <= t_end)) {
    h <- program$h[i]
    a <- attempt(sv$t, sv$y, sv$dydt, h)
    if (is.null(a)) stop(sprintf("a replayed step raised at t = %.17g", sv$t))
    f <- which(sign(a$P) != sign(sv$P))
    if (length(f)) {
      y0 <- sv$y; f0 <- sv$dydt
      lev <- level_of(a$y, a$rates, h)
      M <- (length(y0) - 10) %/% 9
      Pst <- do.call(cbind, a$Pst[-1])
      interior <- rowSums(sign(Pst) != sign(sv$P)) > 0
      switched <- a$K != sv$K
      others <- setdiff(seq_len(M), f)
      kinked <- others[interior[others] | switched[others]]
      smooth <- setdiff(others, kinked)
      idx <- function(js) as.vector(outer(1:9, 9 * (js - 1), "+"))
      interps <- lapply(kinds, function(kd) dense_of(sv$t, y0, f0, a, h, kd))
      names(interps) <- kinds
      for (u in c(0.25, 0.5, 0.75)) {
        r <- attempt(sv$t, y0, f0, u * h)
        if (is.null(r)) next
        for (kd in kinds) {
          if (is.null(interps[[kd]])) next
          err <- abs(interps[[kd]](u) - r$y) / abs(lev)
          rows[[length(rows) + 1]] <- data.frame(row = i, u = u, kind = kd, n_kinked = length(kinked),
            soil = mx(err, soil(y0)), kinked = mx(err, idx(kinked)), smooth = mx(err, idx(smooth)))
        }
      }
    }
    sv$t <- program$time[i]; sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
  }
}
d <- do.call(rbind, rows)
saveRDS(d, OUTF)
cat(sprintf("%s grid at tol %g: %d crossing steps; %d hold a kinked non-crossing member\n", method, tol,
            length(unique(d$row)), length(unique(d$row[d$n_kinked > 0]))))
for (kd in kinds) {
  x <- d[d$kind == kd, ]
  s <- tapply(x$soil, x$row, max); kn <- tapply(x$kinked, x$row, max); sm <- tapply(x$smooth, x$row, max)
  cat(sprintf("  %-7s steps over 1 by the soil %d, by kinked members %d, by smooth members %d; max soil %.3g, kinked %.3g, smooth %.3g; smooth 99%% %.3g\n",
              kd, sum(s > 1), sum(kn > 1), sum(sm > 1), max(s), max(kn), max(sm), quantile(sm, 0.99)))
}
