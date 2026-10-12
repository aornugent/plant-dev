# Round 10: the local ladder around b = 12.03, and per-node end states on its finest level.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075; epsJ <- 0.025
J <- function(g, s) readRDS(file.path(Q, sprintf("rp_%s_%s_dry.rds", g, s)))$stand$J
el <- function(g) (log(J(g, "0.02")) - log(J(g, "-0.02"))) / (2 * u)
lj <- function(g) (log(J(g, "0.02")) + log(J(g, "-0.02"))) / 2
G <- c("Ho", "Hl1", "Hl2", "Hl3", "Hl4"); e <- sapply(G, el); l <- sapply(G, lj)
m <- diff(e) / eps; mj <- diff(l) / epsJ
cat("root_P50 moves (eps):", paste(sprintf("%+.3f", m), collapse = " "), "| ratios", paste(sprintf("%.2f", head(m, -1) / m[-1]), collapse = " "), "\n")
cat("ln J moves (eps):    ", paste(sprintf("%+.3f", mj), collapse = " "), "| ratios", paste(sprintf("%.2f", head(mj, -1) / mj[-1]), collapse = " "), "\n")
p <- readRDS(file.path(Q, "rp_Hl4_0.02_dry.rds"))$stand$nodes; q <- readRDS(file.path(Q, "rp_Hl4_-0.02_dry.rds"))$stand$nodes
k <- which(p$birth > 11.8 & p$birth < 12.62)
d <- data.frame(b = p$birth[k], w = head(p$establishment, -1)[k], nrr = p$nrr[k], d_lnnrr = (log(p$nrr[k]) - log(q$nrr[k])) / (2 * u),
  height = p$height[k], d_height = (p$height[k] - q$height[k]) / (2 * u), mort = p$mortality[k], d_mort = (p$mortality[k] - q$mortality[k]) / (2 * u))
print(round(d, 4))
