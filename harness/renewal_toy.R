## The toy of the Overstorey post on pulse-driven fitness (PR #43): one plant
## under pulsed rain, no competition. It compares the post's fitness, the mean
## lifetime output over germinating rains, with a rare lineage followed through
## its own seed bank on the same series: seeds made each day wait, dying at rate
## delta, and a fraction g of them germinates at each germinating rain.
## Base R, about 3 minutes. docs/schedule/workflows.md §2 cites its output.
set.seed(1)
years <- 10000; lambda <- 1/15; alpha <- 12; k <- 1/25
ndays <- years*365; n_ev <- rpois(1, lambda*ndays)
t_ev <- sort(runif(n_ev, 0, ndays)); d_ev <- rexp(n_ev, 1/alpha)
day <- ceiling(t_ev); inc <- numeric(ndays)
agg <- tapply(d_ev*exp(-k*(day - t_ev)), day, sum)
inc[as.integer(names(agg))] <- agg
x <- numeric(ndays); x[1] <- inc[1]
for (i in 2:ndays) x[i] <- x[i-1]*exp(-k) + inc[i]
x <- x[-(1:3650)]; nd <- length(x)

lifetime_output <- function(x, theta_g = 25, theta_d = 8, D = 90, m = 3*365, L = 40*365,
                            theta_c = 10) {
  nd <- length(x); run <- integer(nd); r <- 0L
  for (i in seq_len(nd)) { r <- if (x[i] < theta_d) r + 1L else 0L; run[i] <- r }
  nk <- rep(.Machine$integer.max, nd); nk[run == D] <- which(run == D)
  nk <- rev(cummin(rev(nk)))
  C <- c(0, cumsum(pmax(x - theta_c, 0))); t0 <- seq_len(nd)
  start <- t0 + m; end <- pmin(nk - 1L, t0 + L, nd)
  out <- ifelse(end >= start, C[end + 1] - C[start], 0)
  out[x <= theta_g] <- 0; out[t0 + L > nd] <- NA; out
}
germinating_rains <- function(x, theta_g = 25)
  which(x[-1] > theta_g & x[-length(x)] <= theta_g) + 1L

RA <- lifetime_output(x); RB <- lifetime_output(x, D = 95, theta_c = 10.2)
ev <- germinating_rains(x); ev <- ev[!is.na(RA[ev]) & !is.na(RB[ev])]
c_scale <- 1/mean(RA[ev])
cat(sprintf("rains/yr %.2f  mean output A %.3f  B %.3f  zero-output cohorts %.2f\n",
            length(ev)/(nd/365), mean(RA[ev]*c_scale), mean(RB[ev]*c_scale),
            mean(RA[ev] == 0)))

## Long-run growth per year of a rare lineage, linear in its own numbers. Every
## cohort alive dies on a lethal day, so cohorts are tracked by cumulative births,
## rebased at each kill and rescaled over the live window only.
lineage <- function(x, D, theta_c, delta, g = 1, theta_d = 8, m = 3*365, L = 40*365,
                    theta_g = 25) {
  nd <- length(x); germ <- logical(nd); germ[germinating_rains(x, theta_g)] <- TRUE
  run <- 0L; bank <- 1; logN <- 0; alive_from <- 1L
  cum <- numeric(nd + 1)
  for (t in seq_len(nd)) {
    run <- if (x[t] < theta_d) run + 1L else 0L
    if (run == D) {
      alive_from <- t + 1L
      w <- max(1L, t - L - 1L):t; cum[w] <- cum[w] - cum[t]
    }
    bank <- bank*exp(-delta)
    born <- 0
    if (germ[t]) { born <- g*bank; bank <- (1 - g)*bank }
    cum[t + 1] <- cum[t] + born
    lo <- max(alive_from, t - L); hi <- t - m
    mature <- if (hi >= lo) cum[hi + 1] - cum[lo] else 0
    bank <- bank + c_scale*mature*max(x[t] - theta_c, 0)
    tot <- bank + (cum[t + 1] - cum[max(alive_from, t - L)])
    if (tot == 0) return(-Inf)
    if (tot > 1e50 || tot < 1e-50) {
      s <- 1/tot; bank <- bank*s; w <- max(1L, t - L - 1L):(t + 1L)
      cum[w] <- cum[w]*s; logN <- logN - log(s)
    }
  }
  (logN + log(bank + (cum[nd + 1] - cum[max(alive_from, nd - L)]))) / (nd/365)
}

for (g in c(1, 0.5, 0.2, 0.05)) for (delta in c(1/(5*365), 1/365)) {
  rA <- lineage(x, 90, 10, delta, g); rB <- lineage(x, 95, 10.2, delta, g)
  cat(sprintf("g %.2f  seed half-life %4.1f yr  growth /yr: A %+.4f  B %+.4f\n",
              g, log(2)/delta/365, rA, rB))
}

## The output scale at which A persists, and B's growth there.
c0 <- c_scale
for (g in c(0.5, 0.2, 0.05)) {
  delta <- 1/(5*365)
  f <- function(lc) { c_scale <<- c0*exp(lc); lineage(x, 90, 10, delta, g) }
  lc <- uniroot(f, c(0, 6), tol = 1e-4)$root
  c_scale <- c0*exp(lc)
  rB <- lineage(x, 95, 10.2, delta, g)
  cat(sprintf("g %.2f: A persists at mean output %.2f; there B grows %+.4f /yr\n",
              g, exp(lc), rB))
}
c_scale <- c0
