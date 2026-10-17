# m9_when.R CASE: when the founders' carbon deficit on res (res - I4, J-weighted founders)
# accrues: increments of the height and storage differences over 4-25 y, split by the soil
# state on I4's record (wet: top layer >= 0.20; drying: below 0.17 and falling; other).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
cs <- commandArgs(TRUE)[1]; a <- rd5(sprintf("trajG_res_%s", cs))$traj; b <- rd5(sprintf("trajG_I4_%s", cs))$traj
tg <- seq(4, 25, by = 0.25 / 365); nf <- length(a$birth)
w <- rd5(sprintf("cl_res_%s", cs))$stand$nodes; ww <- (w$establishment[seq_along(w$nrr)] * w$nrr)[seq_len(nf)]; ww <- ww / sum(ww)
ip <- function(tr, v, j) suppressWarnings(approx(tr$time, tr[[v]][, j], tg)$y)
D <- function(v) sapply(seq_len(nf), function(j) ip(a, v, j) - ip(b, v, j)) %*% ww
dH <- D("height"); dS <- D("storage"); dM <- D("mortality"); top <- suppressWarnings(approx(b$time, b$soil[, 1], tg)$y)
cls <- ifelse(top >= 0.20, "wet", ifelse(top < 0.17 & c(0, diff(top)) < 0, "drying", "other"))
for (v in list(list("height", dH), list("storage", dS), list("mortality", dM))) { inc <- c(0, diff(v[[2]]))
  s <- tapply(inc, cls, sum, na.rm = TRUE); cat(sprintf("%-9s res - I4 change over 4-25 y %+.3e: wet %+.3e, drying %+.3e, other %+.3e | share of time %s\n", v[[1]], sum(inc, na.rm = TRUE), s["wet"], s["drying"], s["other"],
    paste(sprintf("%s %.2f", names(table(cls)), table(cls) / length(cls)), collapse = " "))) }
