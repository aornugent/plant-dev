# m6_state.R CASE: at res's nodes, the final per-cohort state of res against I4 (same birth
# dates): change in ln nrr, mortality integral, ln lifetime seed output (fecundity), height,
# by birth group (median); which part of the fate change is survival and which is output.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
cs <- commandArgs(TRUE)[1]; a <- rd5(sprintf("cl_res_%s", cs)); b <- rd5(sprintf("p5_I4_%s", cs)); b1 <- PIL[[cs]]$b1
k <- match(round(a$stand$nodes$birth, 8), round(b$stand$nodes$birth, 8)); A <- a$stand$nodes$state; B <- b$stand$nodes$state[, k]
g <- log(a$stand$nodes$nrr) - log(b$stand$nodes$nrr[k]); bb <- a$stand$nodes$birth
grp <- cut(bb, c(-1, b1, 10, 17, 25, 99), labels = c("founders", "b1-10", "10-17", "17-25", ">25"))
f <- function(v) paste(sprintf("%s %+.2e", levels(grp), tapply(v, grp, median, na.rm = TRUE)), collapse = ", ")
cat("d ln nrr      ", f(g), "\n"); cat("d mortality   ", f(A["mortality", ] - B["mortality", ]), "\n"); cat("d ln fecundity", f(log(A["fecundity", ]) - log(B["fecundity", ])), "\n")
cat("d height      ", f(A["height", ] - B["height", ]), "\n")
cat("d ln offspring_sw", f(log(A["offspring_produced_survival_weighted", ]) - log(B["offspring_produced_survival_weighted", ])), "\n")
