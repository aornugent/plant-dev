# Fit excess(A) = b + c/A across patch areas.  b is the extrapolated
# infinite-patch excess: zero iff nonlinear averaging over the stochastic
# ensemble accounts for the whole residual gap.
setwd("/home/user/plant-dev")
bb  <- readRDS("probes/out/bigens.rds")
ex  <- readRDS("probes/out/excess-scm.rds")
AGES <- bb$ages; PMAX <- bb$pmax
scm561 <- ex$scm[["561"]][match(AGES, ex$ages)]
scm141 <- ex$scm[["141"]][match(AGES, ex$ages)]
areas  <- as.numeric(names(bb$res))

## ---- per-area means, plain and control-variate adjusted -----------
mu_m <- function(tt) vapply(0:PMAX, function(pp) tt^(pp+1)/(pp+1), 0)  # lambda = 1

est <- list()
for (An in names(bb$res)) {
  r <- bb$res[[An]]; A <- r$area; R <- r$R
  for (ia in seq_along(AGES)) {
    y <- r$L[, ia]
    Mm <- r$M[, ia, , drop=TRUE]                 # R x (PMAX+1)
    mu <- mu_m(AGES[ia])
    d  <- sweep(Mm, 2, mu, "-")
    fit <- lm(y ~ d)
    bhat <- coef(fit)[-1]; bhat[is.na(bhat)] <- 0
    mplain <- mean(y); seplain <- sd(y)/sqrt(R)
    mcv <- mplain - sum(bhat * colMeans(d))
    secv <- sd(residuals(fit))*sqrt((R-1)/(R-PMAX-2))/sqrt(R)
    est[[length(est)+1]] <- data.frame(
      age=AGES[ia], area=A, R=R, mean=mplain, se=seplain, sd=sd(y),
      cv=mcv, secv=secv, r2=summary(fit)$r.squared,
      m0=mean(Mm[,1]), m0exp=mu[1], nc=mean(r$Nc[,ia]))
  }
}
est <- do.call(rbind, est)
est$excess    <- scm561[match(est$age, AGES)] - est$mean
est$excess_cv <- scm561[match(est$age, AGES)] - est$cv
saveRDS(est, "probes/out/34-est.rds")

cat("=== per-area ensemble means (truncated IBM, t<=3.5) ===\n")
cat("cv = control-variate adjusted using exact arrival-time moments\n\n")
for (ia in seq_along(AGES)) {
  cat(sprintf("age %.1f   SCM(561)=%.6f  SCM(141)=%.6f\n", AGES[ia], scm561[ia], scm141[ia]))
  cat(sprintf("  %-6s %-5s %10s %9s | %10s %9s %6s | %10s %9s %8s\n",
      "area","R","mean L","se","cv mean","se(cv)","R2","excess_cv","se","ratio"))
  e <- est[est$age == AGES[ia], ]
  for (i in seq_len(nrow(e))) with(e[i,], cat(sprintf(
      "  %-6g %-5d %10.5f %9.5f | %10.5f %9.5f %6.3f | %10.5f %9.5f %8.4f\n",
      area, R, mean, se, cv, secv, r2, excess_cv, secv, scm561[ia]/cv)))
  cat("\n")
}

cat("=== arrival-process sanity: mean m0 vs exact lambda*t ===\n")
for (ia in seq_along(AGES)) {
  e <- est[est$age == AGES[ia], ]
  cat(sprintf("age %.1f expected %.2f :", AGES[ia], e$m0exp[1]),
      sprintf(" A=%g %.4f", e$area, e$m0), "\n")
}

## ---- weighted fit  excess = b + c/A -------------------------------
fitfun <- function(y, se, A, label, quad=FALSE) {
  x <- 1/A
  X <- if (quad) cbind(1, x, x^2) else cbind(1, x)
  W <- diag(1/se^2, length(y))
  V <- solve(t(X) %*% W %*% X)
  beta <- V %*% t(X) %*% W %*% y
  seb <- sqrt(diag(V))
  fitted <- as.vector(X %*% beta)
  chi2 <- sum((y - fitted)^2/se^2); df <- length(y) - ncol(X)
  list(b=beta[1], se=seb[1], beta=as.vector(beta), sebeta=seb,
       chi2=chi2, df=df, p=if (df>0) pchisq(chi2, df, lower.tail=FALSE) else NA,
       fitted=fitted, label=label)
}

cat("\n=== fit excess(A) = b + c/A  (weighted by 1/se^2) ===\n")
cat(sprintf("%-5s %-26s %11s %10s %22s %11s %8s %8s\n",
    "age","variant","b","se(b)","95% CI for b","c","chi2","p"))
out <- list()
for (ia in seq_along(AGES)) {
  e <- est[est$age == AGES[ia], ]
  o <- e[order(e$area), ]
  variants <- list(
    list("all areas, cv",      seq_len(nrow(o)),           FALSE),
    list("all areas, plain",   seq_len(nrow(o)),           FALSE),
    list("drop A=4, cv",       which(o$area > 4),          FALSE),
    list("all areas, +1/A^2",  seq_len(nrow(o)),           TRUE))
  for (v in variants) {
    idx <- v[[2]]; plain <- grepl("plain", v[[1]])
    yy <- if (plain) o$excess[idx] else o$excess_cv[idx]
    ss <- if (plain) o$se[idx]     else o$secv[idx]
    if (length(idx) - (if (v[[3]]) 3 else 2) < 0) next
    f <- fitfun(yy, ss, o$area[idx], v[[1]], v[[3]])
    cat(sprintf("%-5.1f %-26s %11.5f %10.5f  [%9.5f,%9.5f] %11.5f %8.2f %8.3f\n",
        AGES[ia], v[[1]], f$b, f$se, f$b-1.96*f$se, f$b+1.96*f$se, f$beta[2], f$chi2, f$p))
    if (v[[1]] == "all areas, cv") out[[as.character(AGES[ia])]] <- f
  }
  cat("\n")
}

cat("=== headline: b as a fraction of the deterministic SCM value ===\n")
cat(sprintf("%-5s %11s %11s %11s %22s %14s\n","age","SCM(561)","excess@4m2","b","95% CI for b","b/SCM (%)"))
for (ia in seq_along(AGES)) {
  f <- out[[as.character(AGES[ia])]]
  e4 <- est$excess_cv[est$age==AGES[ia] & est$area==4]
  cat(sprintf("%-5.1f %11.5f %11.5f %11.5f  [%9.5f,%9.5f] %6.2f [%5.2f,%5.2f]\n",
      AGES[ia], scm561[ia], e4, f$b, f$b-1.96*f$se, f$b+1.96*f$se,
      100*f$b/scm561[ia], 100*(f$b-1.96*f$se)/scm561[ia], 100*(f$b+1.96*f$se)/scm561[ia]))
}

## ---- the same fit on the noise-free regular-arrival ladder --------
# Regular arrivals remove recruitment stochasticity entirely, so these points
# carry no Monte Carlo error from the arrival process (only residual mortality
# noise).  Their A -> infinity limit is the deterministic mean field.
rg <- readRDS("probes/out/regular.rds")$res
rgA <- vapply(rg, `[[`, 0, "area")
rgM <- t(vapply(rg, function(z) colMeans(z$L), numeric(length(AGES))))
rgS <- t(vapply(rg, function(z) apply(z$L,2,sd)/sqrt(nrow(z$L)), numeric(length(AGES))))
rgS[rgS <= 0] <- NA
cat("\n=== fit on the regular-arrival ladder (no recruitment noise) ===\n")
cat(sprintf("%-5s %11s %10s %22s %11s %10s\n","age","b","se(b)","95% CI for b","c","b/SCM %"))
for (ia in seq_along(AGES)) {
  ss <- rgS[, ia]; ss[is.na(ss)] <- max(ss, na.rm = TRUE)
  ss <- pmax(ss, 1e-4*scm561[ia])
  f <- fitfun(scm561[ia] - rgM[, ia], ss, rgA, "ladder")
  cat(sprintf("%-5.1f %11.6f %10.6f  [%9.6f,%9.6f] %11.6f %10.2f\n",
      AGES[ia], f$b, f$se, f$b-1.96*f$se, f$b+1.96*f$se, f$beta[2], 100*f$b/scm561[ia]))
}
cat("\nladder means by area (rows = A):\n")
cat(sprintf("%-6s %s\n","A", paste(sprintf("%10s", sprintf("L(%.1f)",AGES)), collapse=" ")))
for (i in order(rgA)) cat(sprintf("%-6g %s   excess %s\n", rgA[i],
    paste(sprintf("%10.6f", rgM[i,]), collapse=" "),
    paste(sprintf("%7.4f", scm561 - rgM[i,]), collapse=" ")))

## ---- direct curvature prediction, now with large R ----------------
cat("\n=== direct curvature: quadratic of L on realised recruitment, per area ===\n")
cat("pred = b2 * Var(driver)  should equal the observed -excess if the gap is nonlinear averaging\n")
cat(sprintf("%-5s %-6s %10s %10s %10s %12s %12s %8s\n",
    "age","area","b2","se(b2)","var(Nc)","pred gap","obs excess","ratio"))
for (ia in seq_along(AGES)) {
  for (An in names(bb$res)) {
    r <- bb$res[[An]]
    y <- r$L[, ia]; x <- r$Nc[, ia]; xc <- x - AGES[ia]
    f <- lm(y ~ xc + I(xc^2))
    b2 <- coef(f)[3]; se2 <- summary(f)$coefficients[3,2]
    pg <- -b2*var(x)
    ob <- est$excess[est$age==AGES[ia] & est$area==r$area]
    cat(sprintf("%-5.1f %-6g %10.5f %10.5f %10.5f %12.5f %12.5f %8.3f\n",
        AGES[ia], r$area, b2, se2, var(x), pg, ob, pg/ob))
  }
  cat("\n")
}
