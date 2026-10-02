# Checks t1_chain.R's one-step chain against the chain alone's own run on disk:
# from each recorded step's start state and size, the ratio and binding layer
# should come back to round-off.
#   nice -n 10 Rscript DEV/rej_class/t1_validate.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
W <- "/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890"
Sys.setenv(PLANT_LIB = file.path(D, "lib_v12t"))
source(file.path(W, "harness", "long_drought.R"))
tab <- new.env()
sys.source(file.path(W, "harness", "ark436.R"), envir = tab)
theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
env <- mkenv("long-drought")
rain_at <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
chain_rates <- function(th, rain) {
  out <- K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
  (cbind(rain * pmax(0, 1 - (th[, 1] / theta_s)^b_inf), out[, 1:4, drop = FALSE]) - out) / dz
}
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + (a[nz] * h) * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}
ck_chain <- function(y0, t0, h, tol, atol) {
  k <- list(chain_rates(y0, rain_at(t0)))
  for (i in 2:6) {
    Y <- combine(y0, tab$ACK[i, ], k, h)
    k[[i]] <- chain_rates(Y, rain_at(t0 + tab$cCK[i] * h))
  }
  y1 <- combine(y0, tab$bCK, k, h)
  e <- combine(0, tab$bCK - tab$dCK, k, h)
  r <- abs(e) / (tol * abs(y1) + atol)
  list(y1 = y1, ratio = r, rmax = apply(r, 1, max), layer = max.col(r, ties.method = "first"))
}
ch <- readRDS(file.path(W, "docs", "measurements", "grid-dynamics", "soil_chain_ld_theta.rds"))
r <- ch$rows
cat("chain run: tol", ch$tol, "rows", nrow(r), "rejected", ch$rejected, "\n")
y0 <- r[, paste0("theta_", 1:5)]
s <- ck_chain(y0, r[, "t0"], r[, "h"], ch$tol, 1e-4 * ch$tol)
rel <- s$rmax / r[, "ratio"] - 1
cat(sprintf("ratio, recomputed over recorded: max |rel diff| %.3g (median %.3g); binding layer agrees on %.4f\n",
            max(abs(rel[r[, "ratio"] > 1e-8])), median(abs(rel)), mean(s$layer == r[, "layer"])))
# The end state of each step should be the next row's start.
nxt <- y0[-1, ]; e1 <- s$y1[-nrow(r), ]
cat(sprintf("end state over next start: max |rel diff| %.3g\n", max(abs(e1 / nxt - 1))))
