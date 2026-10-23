set.seed(1)
J <- matrix(c(0,1,-1,0),2)  # J %*% c(1,0) = c(0,1)
## ---- 1. y_hat is the Lagrange multiplier of the frontier: y_hat = -grad A(sigma)
Q <- crossprod(matrix(rnorm(9),3)) + diag(3); q <- rnorm(3)
B <- matrix(rnorm(6),2)            # S(theta) = B theta, so G = t(B) (k x d)
G <- t(B)
A_of <- function(sig) {
  K <- rbind(cbind(-Q, t(B)), cbind(B, matrix(0,2,2)))
  sol <- solve(K, c(-q, sig)); th <- sol[1:3]
  list(A = -0.5*sum(th*(Q%*%th)) + sum(q*th), th = th, mu = sol[4:5])
}
sig0 <- c(0.3,-0.2); fr <- A_of(sig0); th <- fr$th
grad_a <- -Q%*%th + q
yhat <- -solve(crossprod(G), t(G)%*%grad_a)
h <- 1e-5
gA <- sapply(1:2, function(r){e<-c(0,0);e[r]<-h;(A_of(sig0+e)$A-A_of(sig0-e)$A)/(2*h)})
cat("1. y_hat:", round(yhat,6), " -gradA:", round(-gA,6), "\n")
cat("   T1 residual on frontier:", signif(max(abs(grad_a - G%*%solve(crossprod(G),t(G)%*%grad_a))),3), "\n")
for (ys in list(c(1,2), c(-3,0.5))) {
  g <- grad_a + G%*%ys
  cat("   from site", ys, ":", round(ys - solve(crossprod(G), t(G)%*%g),6), "\n")
}
W <- t(G) %*% solve(Q) %*% G
hA <- matrix(0,2,2); e <- 1e-3
for (r in 1:2) for (s in 1:2) { er<-c(0,0);er[r]<-e; es<-c(0,0);es[s]<-e
  hA[r,s] <- (A_of(sig0+er+es)$A - A_of(sig0+er-es)$A - A_of(sig0-er+es)$A + A_of(sig0-er-es)$A)/(4*e*e) }
cat("   W %*% (-HessA) =", round(W %*% (-hA),5), "\n")

## ---- 2. wrong trade-off: T2 holds under affine sensing; the value of y_hat moves
Tw <- matrix(rnorm(6),3,2)
th_off <- th + c(0.2,-0.1,0.15)
ga <- -Q%*%th_off + q
yh <- function(Tm, ys){ g <- t(Tm)%*%(ga + G%*%ys); GT <- t(Tm)%*%G; ys - solve(crossprod(GT), t(GT)%*%g)}
cat("2. wrong T, y_hat at two sites:", round(yh(Tw,c(1,2)),5), "|", round(yh(Tw,c(-3,.5)),5),
    "; full-trait LS y_hat:", round(yh(diag(3),c(1,2)),5), "\n")
## on the frontier, any T with rank(T'G)=d gives the same y_hat?
ga <- grad_a
cat("   on frontier, T=wrong:", round(yh(Tw,c(1,2)),5), " T=I:", round(yh(diag(3),c(1,2)),5), "\n")
