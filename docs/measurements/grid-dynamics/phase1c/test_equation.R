# Cash-Karp and Dormand-Prince on a pool's test equation y' = -y/tau: each
# stage's value and the step's factor R at h/tau, the h/tau past which the first
# stage turns negative, and the real stability boundary |R| = 1. At tau_s = 7 d,
# the caps tried: 7, 15, 20, 22, 26 days.
#
#   Rscript test_equation.R
tab <- new.env()
sys.source("/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a/harness/ark436.R", envir = tab)
ADP <- matrix(0, 7, 7)
ADP[2, 1] <- 1/5
ADP[3, 1:2] <- c(3/40, 9/40)
ADP[4, 1:3] <- c(44/45, -56/15, 32/9)
ADP[5, 1:4] <- c(19372/6561, -25360/2187, 64448/6561, -212/729)
ADP[6, 1:5] <- c(9017/3168, -355/33, 46732/5247, 49/176, -5103/18656)
ADP[7, 1:6] <- c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84)
bDP <- c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84, 0)
methods <- list("Cash-Karp" = list(A = tab$ACK, b = tab$bCK), "Dormand-Prince" = list(A = ADP, b = bDP))
# The stage values Y_i and R for y' = -y/tau from y = 1, at x = h/tau.
stages <- function(m, x) {
  s <- length(m$b); Y <- numeric(s)
  for (i in seq_len(s)) Y[i] <- 1 - x * sum(m$A[i, seq_len(i - 1)] * Y[seq_len(i - 1)])
  list(Y = Y, R = 1 - x * sum(m$b * Y))
}
tau <- 7
for (k in names(methods)) {
  m <- methods[[k]]
  first_neg <- uniroot(function(x) min(stages(m, x)$Y), c(0.5, 3), tol = 1e-10)$root
  which_stage <- which.min(stages(m, first_neg + 1e-6)$Y)
  stab <- uniroot(function(x) abs(stages(m, x)$R) - 1, c(2.5, 5), tol = 1e-10)$root
  cat(sprintf("%-15s first stage negative past h/tau = %.3f (stage %d; %.1f d at tau_s = 7 d); unstable past %.3f (%.1f d)\n",
              k, first_neg, which_stage, first_neg * tau, stab, stab * tau))
  for (h in c(7, 10, 15, 20, 22, 24, 26)) {
    v <- stages(m, h / tau)
    cat(sprintf("   h = %2d d (h/tau_s %.2f): lowest stage %+.3f (stage %d), R = %+.3f\n", h, h / tau,
                min(v$Y), which.min(v$Y), v$R))
  }
}
# Dormand-Prince's step at which its lowest stage reaches Cash-Karp's lowest at
# 20 and 22 days (the most negative stages walked without a raise) and at 26
# days (where lma x2 raised), and the R it has there.
for (h in c(20, 22, 26)) {
  target <- min(stages(methods[["Cash-Karp"]], h / tau)$Y)
  x <- uniroot(function(x) min(stages(methods[["Dormand-Prince"]], x)$Y) - target, c(1.04, 3.3), tol = 1e-10)$root
  cat(sprintf("Dormand-Prince's lowest stage reaches Cash-Karp's at %d d (%+.3f) at h/tau = %.3f, %.1f d (R %+.3f)\n",
              h, target, x, x * tau, stages(methods[["Dormand-Prince"]], x)$R))
}
