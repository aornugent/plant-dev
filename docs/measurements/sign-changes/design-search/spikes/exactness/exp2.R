# ln J and the elasticity in th1 along th1 * exp(u), u in [-0.01, 0.01], on one
# frozen mesh (plain's adaptive steps at TOL), for one method.
source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
m <- Sys.getenv("METHOD", "plain")
mesh <- run_adaptive(th0, tol, "plain")$times
us <- seq(-0.01, 0.01, length.out = 81)
L <- E <- numeric(length(us))
for (i in seq_along(us)) {
  th <- th0; th[1] <- th0[1] * exp(us[i])
  L[i] <- replay(mesh, th, m)
  E[i] <- elasticity(mesh, th, 1, m)
}
saveRDS(list(u = us, lnJ = L, e1 = E, method = m, tol = tol), sprintf("exp2_%s_%s.rds", m, format(tol)))
fitL <- lm(L ~ us + I(us^2)); fitE <- lm(E ~ us)
cat(sprintf("%s tol %g: lnJ quad-fit resid sd %.3g max %.3g | e1 lin-fit resid sd %.3g max %.3g\n", m, tol,
            sd(resid(fitL)), max(abs(resid(fitL))), sd(resid(fitE)), max(abs(resid(fitE)))))
i0 <- which.min(abs(us)); ip <- length(us); im <- 1
cat(sprintf("  chord at r=1e-2: %.5f   second difference of lnJ at r=1e-2: %.5f   2*quad coef: %.5f\n",
            (E[ip] - E[im]) / 0.02, (L[ip] - 2 * L[i0] + L[im]) / 1e-4, 2 * coef(fitL)[3]))
d <- diff(L) - diff(fitted(fitL)); cat(sprintf("  largest step-to-step departure of lnJ from the fit: %.3g\n", max(abs(d))))
cat(sprintf("  CD elasticity vs d(fit)/du at u=0: %.6f vs %.6f\n", E[i0], coef(fitL)[2]))
