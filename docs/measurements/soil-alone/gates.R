# The build's gates (prereg.txt, 2026-10-07): G1-G4 and G7 read from the runs
# gates.sh saved, each printed with what it compared.
#   DEV=... Rscript gates.R
D <- Sys.getenv("DEV")
G <- file.path(D, "soil_alone", "gates", "runs")
run <- function(name) {
  f <- file.path(G, paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)
}
here <- if (nzchar(Sys.getenv("PLANT_DEV"))) Sys.getenv("PLANT_DEV") else "/home/user/plant-dev"
eps <- read.csv(file.path(here, "docs/measurements/eps.csv"))
eps_of <- function(role, trait) max(eps$eps[eps$role == role & eps$trait == trait], 0.01, na.rm = TRUE)
traits <- c("lma", "d_I", "a_dG1", "a_dG2", "omega")
J_star <- c("long-drought" = 12.6687135, episodic = 1.978902094)
bound_J <- 2.524e-4
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
absent <- function(...) {
  names <- c(...)
  out <- names[!file.exists(file.path(G, paste0(names, ".rds")))]
  if (length(out)) cat("   not run yet:", paste(out, collapse = ", "), "\n")
  length(out) > 0
}

# A plant run's accepted steps: each step's end, size, whether it took the soil
# alone, and the members it carried (introductions at or before its start).
steps_of <- function(o) {
  s <- o$stand
  n <- length(s$times)
  list(time = s$times[-1], h = s$sizes[-1],
       alone = lengths(s$alone_steps[-1]) > 0,
       M = vapply(s$times[-n], function(t) sum(o$node_times <= t), 0))
}
rows <- function(o) sum(steps_of(o)$M)
attempts <- function(o) sum(o$stand$attempts)
same_bits <- function(a, b) length(a) == length(b) && identical(a, b)

cat("== G1, the port: the aligned driver against plant, splits off\n")
for (rec in c("long-drought", "episodic")) {
  if (absent(paste0("drv_", rec), paste0("alone_", rec))) next
  d <- run(paste0("drv_", rec))
  p <- steps_of(run(paste0("alone_", rec)))
  Jp <- run(paste0("alone_", rec))$stand$J
  n <- min(length(d$st$time), length(p$time))
  first <- which(d$st$time[1:n] != p$time[1:n] | d$st$h[1:n] != p$h[1:n] |
                   d$mr[1:n] != p$alone[1:n])[1]
  same <- length(d$st$time) == length(p$time) && is.na(first)
  rel <- abs(d$J / Jp - 1)
  cat(sprintf("   %-12s steps %d / %d, first difference %s, alone %d / %d; J %.12g / %.12g (%.1e)  %s\n",
              rec, length(d$st$time), length(p$time), if (is.na(first)) "none" else first,
              sum(d$mr), sum(p$alone), d$J, Jp, rel, verdict(same && rel <= 1e-12)))
}

cat("== G2, identity: the program's replay, and J' = J at the stand's traits\n")
if (!absent("rep", "alone_split_long-drought")) {
  a <- run("alone_split_long-drought")$stand
  r <- run("rep")$stand
  ok <- identical(r$J, a$J) && same_bits(r$times, a$times) && same_bits(r$sizes, a$sizes)
  cat(sprintf("   replay: J %.17g / %.17g, %d / %d times  %s\n", r$J, a$J,
              length(r$times), length(a$times), verdict(ok)))
}
for (rec in c("long-drought", "episodic")) {
  name <- paste0("alone_split_", rec)
  if (absent(name)) next
  o <- run(name)
  cat(sprintf("   %-12s J' %.17g, J %.17g  %s\n", rec, o$invader$J, o$stand$J,
              verdict(identical(o$invader$J, o$stand$J))))
}

cat("== G3, the sweep through steps taken alone, long drought with splits\n")
if (!absent("alone_split_long-drought", "up", "down")) {
  a <- run("alone_split_long-drought")$stand
  cd <- (log(run("up")$stand$J) - log(run("down")$stand$J)) / (log1p(1e-3) - log1p(-1e-3))
  adj <- a$elasticity[["1.lma"]]
  cat(sprintf("   lma elasticity: adjoint %.8f, central %.8f, difference %.2e (at most 2e-3)  %s\n",
              adj, cd, adj - cd, verdict(abs(adj - cd) <= 2e-3)))
}
if (!absent("alone_split_long-drought", "k1", "k2", "k-1", "k-2")) {
  k <- c(-2, -1, 0, 1, 2)
  lnJ <- c(log(run("k-2")$stand$J), log(run("k-1")$stand$J),
           log(run("alone_split_long-drought")$stand$J),
           log(run("k1")$stand$J), log(run("k2")$stand$J))
  res <- residuals(lm(lnJ ~ k))
  cat(sprintf("   ln J's residual from a line over k x 1e-12: rms %.2e (at most 1e-13)  %s\n",
              sqrt(mean(res^2)), verdict(sqrt(mean(res^2)) <= 1e-13)))
}

cat("== G4, Q3's pass in plant: alone against bnd, and against ref at 1e-5\n")
for (rec in c("long-drought", "episodic")) {
  if (absent(paste0("alone_", rec), paste0("bnd_", rec), paste0("ref_", rec))) next
  a <- run(paste0("alone_", rec))
  b <- run(paste0("bnd_", rec))
  r <- run(paste0("ref_", rec))
  eJ <- a$stand$J / J_star[[rec]] - 1
  cat(sprintf("   %s: rows %.0f / %.0f (%+.1f%%), attempts %d / %d (%+.1f%%), steps alone %d of %d; J/J* - 1 %+.2e (bnd %+.2e)  %s\n",
              rec, rows(a), rows(b), 100 * (rows(a) / rows(b) - 1), attempts(a), attempts(b),
              100 * (attempts(a) / attempts(b) - 1), sum(steps_of(a)$alone), length(steps_of(a)$alone),
              eJ, b$stand$J / J_star[[rec]] - 1,
              verdict(rows(a) < rows(b) && attempts(a) < attempts(b) && abs(eJ) <= bound_J)))
  for (role in c("resident", "invader")) {
    pick <- function(o) (if (role == "resident") o$stand else o$invader)$elasticity[paste0("1.", traits)]
    e <- vapply(traits, function(t) eps_of(role, t), 0)
    da <- abs(pick(a) - pick(r))
    db <- abs(pick(b) - pick(r))
    ok <- da <= e / 3 & da <= db + 0.1 * e
    cat(sprintf("     %-8s %s\n", role, paste(sprintf("%s %.3f eps (bnd %.3f)%s", traits, da / e, db / e,
                                                       ifelse(ok, "", " FAILS")), collapse = ", ")))
  }
}
if (!absent("alone_constant", "bnd_constant")) {
  a <- run("alone_constant")
  b <- run("bnd_constant")
  arkc <- readRDS(file.path(D, "soil_alone", "runs", "arkc_constant.rds"))
  ark_rows <- sum(arkc$st$M)
  cat(sprintf("   constant: rows %.0f, bnd %.0f (%+.1f%%), arkc %.0f (%.2fx)  %s\n",
              rows(a), rows(b), 100 * (rows(a) / rows(b) - 1), ark_rows, rows(a) / ark_rows,
              verdict(rows(a) <= 1.2 * ark_rows)))
}

cat("== G7, off: a share of 0 on PLANT-105 against PLANT-104\n")
pairs <- list(c("off104_long-drought", "bnd_long-drought"),
              c("off104_episodic", "bnd_episodic"),
              c("off104_split", "off105_split"))
for (pr in pairs) {
  if (absent(pr)) next
  x <- run(pr[1])$stand
  y <- run(pr[2])$stand
  ok <- identical(x$J, y$J) && same_bits(x$times, y$times) && same_bits(x$sizes, y$sizes)
  cat(sprintf("   %s against %s: J %.17g / %.17g, %d / %d times  %s\n", pr[1], pr[2],
              x$J, y$J, length(x$times), length(y$times), verdict(ok)))
}
