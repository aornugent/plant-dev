## Lag identity: closed loop of (y, theta), canonical equation theta' = k M g.
## phi(theta; y) = a(theta) + <S(theta), y> + 0.5 * c2 * y' Gam(theta) y  (non-affine allowed)
set.seed(2)
c2 <- 0.3
a  <- function(th) -0.5*sum(th^2) - 0.1*sum(th^4) + 0.2*th[1]*th[2]
S  <- function(th) c(th[1] + 0.3*th[1]*th[2], th[2] - 0.2*th[1]^2)
phi <- function(th, y) a(th) + sum(S(th)*y) + 0.5*c2*(th[1]^2)*sum(y^2)
num_grad <- function(f, x, h=1e-6) sapply(seq_along(x), function(i){e<-0*x;e[i]<-h;(f(x+e)-f(x-e))/(2*h)})
g_of   <- function(th, y) num_grad(function(t) phi(t, y), th)
sig_of <- function(th, y) num_grad(function(z) phi(th, z), y)   # what the cut returns
kM <- matrix(c(0.6, 0.2, 0.2, 0.3), 2)
loop <- function(t, w, u, v) u*cos(w*t) + v*sin(w*t)
dloop <- function(t, w, u, v) w*(-u*sin(w*t) + v*cos(w*t))
run <- function(w, u, v, periods=30, nstep=4000) {
  P <- 2*pi/w; dt <- P/nstep; th <- c(0,0); t <- 0
  f <- function(t, th) as.vector(kM %*% g_of(th, loop(t,w,u,v)))
  for (p in 1:(periods-1)) for (i in 1:nstep) {           # spin up to the periodic orbit
    k1<-f(t,th);k2<-f(t+dt/2,th+dt/2*k1);k3<-f(t+dt/2,th+dt/2*k2);k4<-f(t+dt,th+dt*k3)
    th <- th + dt/6*(k1+2*k2+2*k3+k4); t <- t+dt }
  TH <- matrix(0, nstep+1, 2); TH[1,] <- th; Ts <- t + (0:nstep)*dt
  for (i in 1:nstep) { k1<-f(t,th);k2<-f(t+dt/2,th+dt/2*k1);k3<-f(t+dt/2,th+dt/2*k2);k4<-f(t+dt,th+dt*k3)
    th <- th + dt/6*(k1+2*k2+2*k3+k4); t <- t+dt; TH[i+1,] <- th }
  list(TH=TH, Ts=Ts, dt=dt, w=w, u=u, v=v)
}
trap <- function(x, dt) dt*(sum(x) - 0.5*(x[1]+x[length(x)]))
r <- run(w=2*pi/10, u=c(1.2,0), v=c(0.3,0.9))
n <- nrow(r$TH)
lhs <- sapply(1:n, function(i){ y<-loop(r$Ts[i],r$w,r$u,r$v); sum(sig_of(r$TH[i,],y)*dloop(r$Ts[i],r$w,r$u,r$v)) })
rhs <- sapply(1:n, function(i){ y<-loop(r$Ts[i],r$w,r$u,r$v); g<-g_of(r$TH[i,],y); -sum(g*(kM%*%g)) })
cat("Loop integral <sigma,dy>:", signif(trap(lhs,r$dt),6), "  -int g'kMg dt:", signif(trap(rhs,r$dt),6),
    "  closure |theta(P)-theta(0)|:", signif(sqrt(sum((r$TH[n,]-r$TH[1,])^2)),3), "\n")
## discrete cycle sums on n dates (exact table entries), forward vs against history
for (nd in c(2,3,4,6,12)) {
  idx <- round(seq(1, n, length.out=nd+1))[1:nd]
  ys <- lapply(idx, function(i) loop(r$Ts[i],r$w,r$u,r$v)); ths <- lapply(idx, function(i) r$TH[i,])
  fwd <- sum(sapply(1:nd, function(j){ jn <- j %% nd + 1; phi(ths[[j]], ys[[jn]]) - phi(ths[[j]], ys[[j]]) }))
  rev <- sum(sapply(1:nd, function(j){ jp <- (j-2) %% nd + 1; phi(ths[[j]], ys[[jp]]) - phi(ths[[j]], ys[[j]]) }))
  cat(sprintf("  %2d dates: cycle along history %+.4f, against history %+.4f\n", nd, fwd, rev))
}
