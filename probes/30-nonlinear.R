# Step 1: free reanalysis of the existing oracle ensemble.
#  (a) per-area excess of the corrected SCM over the IBM ensemble mean;
#  (b) direct curvature estimate: regress leaf area on realised recruitment,
#      predict the nonlinear-averaging bias as (1/2) f''(mu) Var(driver),
#      compare with the observed gap.
setwd("/home/user/plant-dev")
o <- readRDS("probes/out/oracle-ibm.rds")
ex <- readRDS("probes/out/excess-scm.rds")
AGES <- c(1, 1.5, 2, 2.5, 3)
grid <- o$grid
ji   <- vapply(AGES, function(a) which.min(abs(grid - a)), 1L)
areas <- c(4, 16, 64)

scm <- setNames(ex$scm[["561"]][match(AGES, ex$ages)], AGES)   # best-resolved SCM
scm141 <- setNames(ex$scm[["141"]][match(AGES, ex$ages)], AGES)
cat("grid points used:", paste(sprintf("%.2f", grid[ji]), collapse=" "), "\n")
cat("SCM (n=561):", sprintf("%.6f", scm), "\n")
cat("SCM (n=141):", sprintf("%.6f", scm141), "\n\n")

## ---------------------------------------------------------------- (a)
cat("=== (a) per-area ensemble mean and excess ===\n")
cat(sprintf("%-5s %-5s %-4s %10s %10s %10s %10s %10s\n",
            "age","area","R","mean L","sd L","se L","excess","ratio"))
tab <- list()
for (ia in seq_along(AGES)) {
  a <- AGES[ia]; j <- ji[ia]
  for (A in areas) {
    L <- o$out[[as.character(A)]]$L[, j, 1]
    R <- length(L); m <- mean(L); s <- sd(L); se <- s/sqrt(R)
    tab[[length(tab)+1]] <- data.frame(age=a, area=A, R=R, mean=m, sd=s, se=se,
                                       excess=scm[ia]-m, ratio=scm[ia]/m,
                                       se_ratio=scm[ia]*se/m^2)
    cat(sprintf("%-5.1f %-5g %-4d %10.5f %10.5f %10.5f %10.5f %10.3f\n",
                a, A, R, m, s, se, scm[ia]-m, scm[ia]/m))
  }
  cat("\n")
}
tab <- do.call(rbind, tab)
saveRDS(tab, "probes/out/30-perarea.rds")

## driver summaries -------------------------------------------------
cat("=== recruitment driver: cumulative recruits/m2 (Nc) ===\n")
cat(sprintf("%-5s %-5s %10s %10s %12s %12s\n","age","area","mean Nc","sd Nc","var Nc","var*A"))
for (ia in seq_along(AGES)) { a <- AGES[ia]; j <- ji[ia]
  for (A in areas) {
    x <- o$out[[as.character(A)]]$Nc[, j]
    cat(sprintf("%-5.1f %-5g %10.4f %10.4f %12.5f %12.4f\n",
                a, A, mean(x), sd(x), var(x), var(x)*A))
  }
}
cat("\nliving N vs cumulative Nc at each age (area 4):\n")
for (ia in seq_along(AGES)) cat(sprintf("  age %.1f  N=%.4f  Nc=%.4f\n", AGES[ia],
   mean(o$out[["4"]]$N[,ji[ia]]), mean(o$out[["4"]]$Nc[,ji[ia]])))

## ---------------------------------------------------------------- (b)
# Pool all 16 replicates. Model  L = b0 + b0_area + b1*(x-mu) + b2*(x-mu)^2
# with mu the theoretical (deterministic) driver mean.  Predicted
# nonlinear-averaging bias for area A is  b2 * Var_A(x).
cat("\n=== (b) curvature of L on realised recruitment ===\n")

fit_one <- function(a_idx, drv_idx, label) {
  j <- ji[a_idx]; jd <- ji[drv_idx]
  d <- do.call(rbind, lapply(areas, function(A) {
    data.frame(area=factor(A),
               A=A,
               L = o$out[[as.character(A)]]$L[, j, 1],
               x = o$out[[as.character(A)]]$Nc[, jd])
  }))
  mu <- weighted.mean(tapply(d$x, d$A, mean), tapply(d$x, d$A, length))
  # deterministic driver mean: use the large-area (64 m2) mean as best proxy
  mu64 <- mean(d$x[d$A == 64])
  d$xc <- d$x - mu64
  f2 <- lm(L ~ xc + I(xc^2), data = d)
  f1 <- lm(L ~ xc, data = d)
  b2 <- coef(f2)[3]; se2 <- summary(f2)$coefficients[3,2]
  vA <- vapply(areas, function(A) var(d$x[d$A==A]), 0)
  pred <- b2 * vA           # E[f] - f(mu)  (should be negative)
  list(label=label, b2=b2, se2=se2, p2=summary(f2)$coefficients[3,4],
       mu=mu64, vA=setNames(vA, areas), pred=setNames(pred, areas),
       f2=f2, f1=f1, d=d, r2=summary(f2)$r.squared, r2lin=summary(f1)$r.squared)
}

for (drv_age in c(1, 1.5, 2)) {
  di <- match(drv_age, AGES)
  cat(sprintf("\n--- driver = Nc at age %.1f ---\n", drv_age))
  cat(sprintf("%-5s %12s %12s %8s %8s | %s\n","age","b2 (=f''/2)","se(b2)","p","R2",
              "predicted gap  A=4 / 16 / 64   vs observed"))
  for (ia in seq_along(AGES)) {
    if (AGES[ia] < drv_age) next
    r <- fit_one(ia, di, "")
    obs <- vapply(areas, function(A) scm[ia] - mean(o$out[[as.character(A)]]$L[,ji[ia],1]), 0)
    cat(sprintf("%-5.1f %12.5f %12.5f %8.4f %8.3f | %9.5f %9.5f %9.5f  vs %9.5f %9.5f %9.5f\n",
        AGES[ia], r$b2, r$se2, r$p2, r$r2,
        -r$pred[1], -r$pred[2], -r$pred[3], obs[1], obs[2], obs[3]))
  }
}

## per-area quadratic (area 4 only, R=8) as a sanity check ----------
cat("\n--- area-4-only quadratic, driver = Nc at same age ---\n")
for (ia in seq_along(AGES)) {
  j <- ji[ia]
  d <- data.frame(L=o$out[["4"]]$L[,j,1], x=o$out[["4"]]$Nc[,j])
  d$xc <- d$x - mean(o$out[["64"]]$Nc[,j])
  f <- lm(L ~ xc + I(xc^2), data=d)
  b2 <- coef(f)[3]; se2 <- summary(f)$coefficients[3,2]
  obs <- scm[ia] - mean(d$L)
  cat(sprintf("age %-4.1f b2=%10.5f (se %8.5f)  var=%8.5f  pred gap=%9.5f  obs=%9.5f\n",
      AGES[ia], b2, se2, var(d$x), -b2*var(d$x), obs))
}

## how many extra replicates? ---------------------------------------
cat("\n=== sizing new replicates ===\n")
cat("target: se(mean L) small vs the 4-vs-16 m2 difference in mean L\n")
for (ia in seq_along(AGES)) {
  j <- ji[ia]
  m4 <- mean(o$out[["4"]]$L[,j,1]); s4 <- sd(o$out[["4"]]$L[,j,1])
  m16<- mean(o$out[["16"]]$L[,j,1]); s16<- sd(o$out[["16"]]$L[,j,1])
  m64<- mean(o$out[["64"]]$L[,j,1]); s64<- sd(o$out[["64"]]$L[,j,1])
  dif <- m16 - m4
  cat(sprintf("age %-4.1f  cv4=%.3f cv16=%.3f cv64=%.3f  m16-m4=%.5f  R for se=dif/5: 4m2 %5.0f  16m2 %5.0f\n",
      AGES[ia], s4/m4, s16/m16, s64/m64, dif, (5*s4/dif)^2, (5*s16/dif)^2))
}
