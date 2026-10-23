set.seed(3)
## Linear tracking: theta' = kM (g0 + H theta + G y); sigma = G' theta (+ const)
k <- 3; d <- 2
H <- -(crossprod(matrix(rnorm(9),3)) + diag(3)); G <- matrix(rnorm(6),3,2)
kM <- crossprod(matrix(rnorm(9),3))/3 + diag(3)*0.2
L <- -kM %*% H
Tf <- function(w) t(G) %*% solve(1i*w*diag(3) + L) %*% kM %*% G
W0 <- t(G) %*% solve(-H) %*% G
V  <- t(G) %*% solve(-H) %*% solve(kM) %*% solve(-H) %*% G
u <- c(1,0.2); v <- c(-0.3,0.8); z <- u - 1i*v
for (w in c(0.01, 0.1, 0.5)) {
  exact <- pi*Im(Conj(z) %*% Tf(w) %*% z)
  first <- -pi*w*(sum(u*(V%*%u)) + sum(v*(V%*%v)))
  ## brute force: simulate the linear ODE response in steady state via the transfer function
  cat(sprintf("w=%.2f loop integral exact %.6f, first order %.6f, -int g'kMg (Parseval) %.6f\n",
      w, Re(exact), first,
      { dth <- solve(1i*w*diag(3)+L) %*% kM %*% G %*% z      # complex amplitude of theta
        gz <- H %*% dth + G %*% z                            # complex amplitude of g
        -(2*pi/w)*0.5*Re(Conj(t(gz)) %*% kM %*% gz) }))
}
## skew ratio of the fitted map for a round loop, isotropic-in-W0 coordinates
w <- 0.3; Tw <- Tf(w); P <- Re(Tw); Qm <- Im(Tw)
J <- matrix(c(0,1,-1,0),2)
Mhat <- P + Qm %*% J                      # sigma = Mhat y on the loop y = (cos, sin)
sk <- (Mhat - t(Mhat))/2; sy <- (Mhat + t(Mhat))/2
cat("skew/sym (trace-normalised):", abs(sk[2,1])/(sum(diag(sy))/2),
    " predicted w*trV/trW0:", w*sum(diag(V))/sum(diag(W0)), "\n")

## flat loops: pairs see the lag when tan(delta) > 2 eps/(1-eps^2)
pair_fail <- function(delta, eps) { Mh <- matrix(c(cos(delta), -eps*sin(delta), sin(delta)/eps, cos(delta)),2)
  min(eigen((Mh+t(Mh))/2)$values) < 0 }
for (delta in c(0.2, 0.64)) { e_crit <- uniroot(function(e) 2*e/(1-e^2) - tan(delta), c(1e-6, 0.999))$root
  cat(sprintf("delta=%.2f: eps_crit %.3f; pair fails at eps=%.3f? %s, at %.3f? %s\n", delta, e_crit,
      e_crit*0.95, pair_fail(delta, e_crit*0.95), e_crit*1.05, pair_fail(delta, e_crit*1.05))) }

## design: n sites on a circle, rotation delta, entry noise eps: SNR(n) of the best regular cycle
snr <- function(n, delta) n*(cos(2*pi/n - delta) - cos(delta))/sqrt(2*n)
for (delta in c(0.2, 0.64)) { ns <- 3:200; s <- snr(ns, delta)
  cat(sprintf("delta=%.2f threshold pi/delta=%.1f, SNR-optimal n=%d, 3pi/delta=%.1f\n",
      delta, pi/delta, ns[which.max(s)], 3*pi/delta)) }

## GARP (free positive multipliers) on the regular n-gon: same threshold as cyclic monotonicity
garp_fail <- function(n, delta) { th <- 2*pi*(0:(n-1))/n; y <- rbind(cos(th), sin(th))
  R <- matrix(c(cos(delta), sin(delta), -sin(delta), cos(delta)),2)
  kap <- exp(rnorm(n)); sg <- R %*% y %*% diag(kap)
  steps <- sapply(1:n, function(j) sum(sg[,j]*(y[,j%%n+1]-y[,j])))
  all(steps > 0) }
cat("GARP fails (n=6): delta=0.50", garp_fail(6,0.5), " delta=0.55", garp_fail(6,0.55), "(pi/6=0.524)\n")
