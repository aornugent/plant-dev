# tolwhere.R CASE: where in birth date the tolerance (1e-4 -> 3e-4) moves J, per node of
# the inset pair: establishment-weighted nrr change, near an edge (within D days) or not.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; D <- 20 / 365; et <- edge_table(cs)
ld <- function(n) readRDS(file.path(POUT, "runs", paste0(n, "_", cs, ".rds")))$stand
for (side in c("c", "f")) { a <- ld(paste0("P_ins", side)); b <- ld(paste0("P_ins3", side)); nb <- a$nodes; n3 <- b$nodes
  stopifnot(all.equal(nb$birth, n3$birth)); w <- head(nb$establishment, length(nb$birth))
  dJ <- w * (n3$nrr - nb$nrr); near <- vapply(nb$birth, function(t) any(abs(et$b - t) < D), TRUE)
  cat(sprintf("%s %s: n %d (near %d) | sum dJ/J %+.2e: near %+.2e, far %+.2e | |dJ| near %.2e far %.2e | before b=1 %+.2e\n", cs, side, length(w), sum(near),
    sum(dJ) / a$J, sum(dJ[near]) / a$J, sum(dJ[!near]) / a$J, sum(abs(dJ[near])) / a$J, sum(abs(dJ[!near])) / a$J, sum(dJ[nb$birth < 1]) / a$J))
  o <- order(-abs(dJ)); print(round(data.frame(birth = nb$birth[o], dJrel = dJ[o] / a$J, nrr = nb$nrr[o], near = near[o])[1:8, ], 6)) }
