## Kantorovich certificate for the one-site inverse y_hat = y_s - G_s^{-1} g_s under non-affine sensing
c2 <- 0.3
th <- c(0.7, -0.4)                      # one species' traits, held fixed
g_of <- function(y) {                   # grad_theta phi for phi of lag.R
  num <- function(f, x, h=1e-6) sapply(seq_along(x), function(i){e<-0*x;e[i]<-h;(f(x+e)-f(x-e))/(2*h)})
  num(function(t) -0.5*sum(t^2) - 0.1*sum(t^4) + 0.2*t[1]*t[2] +
        sum(c(t[1] + 0.3*t[1]*t[2], t[2] - 0.2*t[1]^2)*y) + 0.5*c2*(t[1]^2)*sum(y^2), th) }
G_of <- function(y, h=1e-5) sapply(1:2, function(r){e<-c(0,0);e[r]<-h;(g_of(y+e)-g_of(y-e))/(2*h)})
ytrue <- { y <- c(0,0); for (i in 1:50) y <- y - solve(G_of(y), g_of(y)); y }
L <- 2*c2*abs(th[1])                    # Lipschitz constant of G in y (spectral norm bound)
for (ys in list(c(0.5,0.3), c(-0.8,0.9), c(1.5,-1.2), c(3,2.5))) {
  Gs <- G_of(ys); gs <- g_of(ys); beta <- norm(solve(Gs), "2"); eta <- sqrt(sum(solve(Gs, gs)^2))
  hk <- beta*L*eta; yh <- ys - solve(Gs, gs)
  err <- sqrt(sum((yh - ytrue)^2))
  bound <- if (hk <= 0.5) (1 - sqrt(1-2*hk))/(beta*L) - eta else NA
  cat(sprintf("site (%+.1f,%+.1f): h=%.3f  |y_hat - y*|=%.4f  certified bound %s\n",
      ys[1], ys[2], hk, err, ifelse(is.na(bound), "none (h>1/2)", sprintf("%.4f", bound))))
}
cat("y* =", round(ytrue,4), "\n")
