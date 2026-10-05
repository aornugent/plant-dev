# Item 4's rows from curvature_rows.sh's runs (prereg.txt, sixteenth extension).
#   OUTD=... SPREAD=dev/curv Rscript curvature_rows.R
outd <- Sys.getenv("OUTD")
run <- function(name) readRDS(file.path(outd, paste0(name, ".rds")))
lma0 <- 0.32

# Each entry's eps: a tenth of its spread over the eight records; none where the
# entry is the same on every record.
eps_of <- function(role) {
  s <- readRDS(file.path(Sys.getenv("SPREAD"), sprintf("spread_%s.rds", role)))
  e <- s$sd / 10
  e[s$sd <= 1e-10 * pmax(abs(s$mean), 1)] <- NA
  e[names(e) != "lma_combined"]
}
eps <- list(resident = eps_of("resident"), invader = eps_of("invader"))
eps$selection <- eps$invader

# A run's ln(lma / lma0); the stand at theta0 took no gradient, so it has no theta.
u_of <- function(x) if (is.null(x$theta)) 0 else log(x$theta[["1.lma"]] / lma0)
# The invader walked on the stand at theta0 at u, by its own lma.
walked <- function(s0, sign, d) {
  for (x in s0$invaders) if (abs(u_of(x) - sign * d) < 1e-9) return(x)
  stop("no invader at u = ", sign * d)
}
# Each row's two ends at D on grid g, and the stand at theta0 there.
ends <- function(role, g, d) {
  tag <- if (d == 1e-2) "1" else "3"
  s0 <- run(paste0("s0_", g))
  switch(role,
         resident = list(run(sprintf("m_%s_p%s", g, tag))$stand,
                         run(sprintf("m_%s_m%s", g, tag))$stand, s0$stand),
         invader = list(walked(s0, 1, d), walked(s0, -1, d), s0$invader),
         selection = list(run(sprintf("m_%s_p%s", g, tag))$invader,
                          run(sprintf("m_%s_m%s", g, tag))$invader, NULL))
}
row_of <- function(role, g, d) {
  x <- ends(role, g, d)
  (x[[1]]$elasticity - x[[2]]$elasticity) / (u_of(x[[1]]) - u_of(x[[2]]))
}
# The second difference of ln J over the row's three points.
second_of <- function(role, g, d) {
  x <- ends(role, g, d)
  up <- u_of(x[[1]]); um <- u_of(x[[2]]); u0 <- u_of(x[[3]])
  f <- log(c(x[[1]]$J, x[[3]]$J, x[[2]]$J))
  2 * ((f[1] - f[2]) / (up - u0) - (f[2] - f[3]) / (u0 - um)) / (up - um)
}
verdict <- function(role, a, b) {
  e <- eps[[role]][names(a)]
  dev <- abs(a - b) / e
  bad <- which(!is.na(dev) & dev > 1/3)
  sprintf("%s (largest %.2f eps, %s)%s",
          if (length(bad)) "fails" else "holds", max(dev, na.rm = TRUE),
          sub("^1\\.", "", names(which.max(dev))),
          if (length(bad)) paste0(": ", paste(sprintf("%s %.2f", sub("^1\\.", "", names(a)[bad]),
                                                      dev[bad]), collapse = ", ")) else "")
}

for (role in c("resident", "invader", "selection")) {
  cat(sprintf("\n== the %s's row, d e_k / d ln lma\n", role))
  r1 <- row_of(role, "g0", 1e-2)
  r3 <- row_of(role, "g0", 3e-2)
  if (role != "selection") {
    for (d in c(1e-2, 3e-2)) {
      ch <- row_of(role, "g0", d)[["1.lma"]]
      s2 <- second_of(role, "g0", d)
      cat(sprintf("lma at D = %g: chord %.4f, second difference %.4f, 2 (ln J)'' - chord %.4f\n",
                  d, ch, s2, 2 * s2 - ch))
    }
    s6 <- abs(r1[["1.lma"]] - second_of(role, "g0", 1e-2)) / eps[[role]][["1.lma"]]
    cat(sprintf("S6 (lma's chord within eps/3 of the second difference at 1e-2): %.2f eps, %s\n",
                s6, if (s6 <= 1/3) "holds" else "fails"))
  }
  cat("S7 (1e-2 against 3e-2):", verdict(role, r1, r3), "\n")
  for (g in c("gm", "gp")) {
    cat(sprintf("S8 (%s against G0 at 1e-2): %s\n", g, verdict(role, row_of(role, g, 1e-2), r1)))
  }
  rows <- cbind(D1e2 = r1, D3e2 = r3, gm = row_of(role, "gm", 1e-2),
                gp = row_of(role, "gp", 1e-2), eps = eps[[role]][names(r1)])
  rownames(rows) <- sub("^1\\.", "", rownames(rows))
  print(signif(rows, 5))
}

s0 <- run("s0_g0")
cat(sprintf("\nThe invader at theta0 against the stand on G0: ln J' - ln J = %.3e\n",
            log(s0$invader$J) - log(s0$stand$J)))
for (g in c("g0", "gm", "gp")) {
  x <- run(paste0("grid_", g))$stand
  cat(sprintf("grid %s: %d steps, %d node steps split, J %.10f\n", g, length(x$times) - 1,
              sum(x$splits), x$J))
}
