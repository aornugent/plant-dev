# The tableaus the stepper scope compares: ARK4(3)6L[2]SA (Kennedy & Carpenter
# 2003, as SUNDIALS' ARK436L2SA_ERK_6_3_4 / ARK436L2SA_DIRK_6_3_4), Cash-Karp
# and Dormand-Prince 5(4).
# Run, it prints the order conditions, the stability boundaries, and where each
# keeps a decaying mode y' = -y/T positive: the pool's question. Sourced, it
# defines the tableaus only.
#
#   Rscript harness/ark436.R
s <- 6
one <- rep(1, s)
AI <- matrix(0, s, s)
AE <- matrix(0, s, s)
AI[2, 1:2] <- c(1/4, 1/4)
AI[3, 1:3] <- c(8611/62500, -1743/31250, 1/4)
AI[4, 1:4] <- c(5012029/34652500, -654441/2922500, 174375/388108, 1/4)
AI[5, 1:5] <- c(15267082809/155376265600, -71443401/120774400,
                730878875/902184768, 2285395/8070912, 1/4)
AI[6, 1:6] <- c(82889/524892, 0, 15625/83664, 69875/102672, -2260/8211, 1/4)
AE[2, 1] <- 1/2
AE[3, 1:2] <- c(13861/62500, 6889/62500)
AE[4, 1:3] <- c(-116923316275/2393684061468, -2731218467317/15368042101831,
                9408046702089/11113171139209)
AE[5, 1:4] <- c(-451086348788/2902428689909, -2682348792572/7519795681897,
                12662868775082/11960479115383, 3355817975965/11060851509271)
AE[6, 1:5] <- c(647845179188/3216320057751, 73281519250/8382639484533,
                552539513391/3454668386233, 3354512671639/8306763924573,
                4040/17871)
b <- c(82889/524892, 0, 15625/83664, 69875/102672, -2260/8211, 1/4)
d <- c(4586570599/29645900160, 0, 178811875/945068544, 814220225/1159782912,
       -3700637/11593932, 61727/225920)
cc <- c(0, 1/2, 83/250, 31/50, 17/20, 1)
ACK <- matrix(0, s, s)
ACK[2, 1] <- 1/5
ACK[3, 1:2] <- c(3/40, 9/40)
ACK[4, 1:3] <- c(3/10, -9/10, 6/5)
ACK[5, 1:4] <- c(-11/54, 5/2, -70/27, 35/27)
ACK[6, 1:5] <- c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096)
bCK <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
dCK <- c(2825/27648, 0, 18575/48384, 13525/55296, 277/14336, 1/4)
cCK <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
# Dormand-Prince 5(4): six stages and the rates at the step's end, whose weight
# is zero in the solution and 1/40 in the embedded one (dDP has seven).
ADP <- matrix(0, s, s)
ADP[2, 1] <- 1/5
ADP[3, 1:2] <- c(3/40, 9/40)
ADP[4, 1:3] <- c(44/45, -56/15, 32/9)
ADP[5, 1:4] <- c(19372/6561, -25360/2187, 64448/6561, -212/729)
ADP[6, 1:5] <- c(9017/3168, -355/33, 46732/5247, 49/176, -5103/18656)
bDP <- c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84)
dDP <- c(5179/57600, 0, 7571/16695, 393/640, -92097/339200, 187/2100, 1/40)
cDP <- c(0, 1/5, 3/10, 4/5, 8/9, 1)
# Its order-4 dense output (Hairer's contd5) on the seven rates.
eDP <- c(-12715105075/11282082432, 0, 87487479700/32700410799,
         -10690763975/1880347072, 701980252875/199316789632,
         -1453857185/822651844, 69997945/29380423)
# Cash-Karp's order-4 dense output on its six stages and the rates at the step's
# end: weight i at u is sum_m BCK4[m, i] u^m. It is the C1 quartic whose order-5
# error at u = 1/2 is least; the six stages alone admit none.
BCK4 <- rbind(c(1, 0, 0, 0, 0, 0, 0),
              c(-156473/57792, 0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
              c(729889/260064, 0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
              c(-24797/24768, 0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
# The ARK pair's dense output on its six stages and the rates at the step's end,
# one set of weights for both parts: order 3, and order 4 on the members' explicit
# trees; C1. Neither the six stages nor the end's rates admit order 4 overall.
BARK3 <- rbind(c(1, 0, 0, 0, 0, 0, 0),
               c(-3.4839678255451552, 0, 8.4045134078518569, -9.974721919052044,
                 7.7343146555992819, 6.8377050543765074, -9.5178433732304448),
               c(4.5996008317369963, 0, -16.061991053607709, 22.671705019341427,
                 -16.569591435178591, -12.675410108753015, 18.03568674646089),
               c(-1.9577167110301694, 0, 7.8442365862798535, -12.016417804980048,
                 8.5600362485843018, 6.0877050543765074, -8.5178433732304448))

if (sys.nframe() == 0L) {
  # The order conditions of an additive pair: every product of the two tableaus.
  conditions <- function(w, p) {
    A <- list(AE, AI)
    r <- c(sum(w) - 1, sum(w * cc) - 1/2)
    if (p >= 3) {
      r <- c(r, sum(w * cc^2) - 1/3)
      for (X in A) r <- c(r, sum(w * (X %*% cc)) - 1/6)
    }
    if (p >= 4) {
      r <- c(r, sum(w * cc^3) - 1/4)
      for (X in A) r <- c(r, sum(w * cc * (X %*% cc)) - 1/8, sum(w * (X %*% cc^2)) - 1/12)
      for (X in A) for (Y in A) r <- c(r, sum(w * (X %*% (Y %*% cc))) - 1/24)
    }
    r
  }
  cat("row sums against c:", format(max(abs(rowSums(AI) - cc), abs(rowSums(AE) - cc)), digits = 3), "\n")
  cat("order 4 (b):", format(max(abs(conditions(b, 4))), digits = 3),
      "  order 3 (d):", format(max(abs(conditions(d, 3))), digits = 3), "\n")

  # For y' = z y the stage values are (I - zA)^-1 1 and the step is 1 + z b'(stages).
  stages <- function(z, A) solve(diag(s) - z * A, one)
  step <- function(z, A, w) 1 + z * sum(w * stages(z, A))
  x <- seq(0, 10, by = 1e-4)
  boundary <- function(A, w) x[which(sapply(-x, function(z) abs(step(z, A, w)) > 1 + 1e-12))[1] - 1]
  cat("\nreal stability boundary, h/T: Cash-Karp", boundary(ACK, bCK), " Dormand-Prince", boundary(ADP, bDP),
      " ARK explicit", boundary(AE, b), "\n")
  cat("implicit part: R(-inf) main", format(step(-1e6, AI, b), digits = 3),
      " embedded", format(step(-1e6, AI, d), digits = 3), "\n")

  # Where a stage first goes negative on a decaying mode; NA where it never does
  # before h/T = 10 (explicit) or h*lambda = 1e7 (implicit).
  first_negative <- function(A, grid) {
    v <- sapply(-grid, function(z) stages(z, A))
    apply(v, 1, function(row) { k <- which(row < 0)[1]; if (is.na(k)) NA else grid[k] })
  }
  cat("\nfirst negative stage value, h/T, per stage 1..6:\n")
  cat("  Cash-Karp    ", format(first_negative(ACK, x), digits = 4), "\n")
  cat("  ARK explicit ", format(first_negative(AE, x), digits = 4), "\n")
  cat("  ARK implicit ", format(first_negative(AI, 10^seq(-2, 7, length.out = 20000)), digits = 4), "\n")
}
