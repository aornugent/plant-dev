# Round 6: root_P50 and ln J moves on the open-side ladder against round 5's, and the
# side of each Ho edge node in Ho's own +-2% runs.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075; epsJ <- 0.025
J <- function(g, s) readRDS(file.path(Q, sprintf("rp_%s_%s_dry.rds", g, s)))$stand$J
el <- function(g) (log(J(g, "0.02")) - log(J(g, "-0.02"))) / (2 * u)
lj <- function(g) (log(J(g, "0.02")) + log(J(g, "-0.02"))) / 2
lad <- function(gs) { e <- sapply(gs, el); l <- sapply(gs, lj); m <- diff(e) / eps; mj <- diff(l) / epsJ
  cat(sprintf("%-18s root_P50 %s | moves %s eps (ratio %.2f) | ln J moves %s eps (ratio %.2f)\n", paste(gs, collapse = "->"),
    paste(sprintf("%.5f", e), collapse = " "), paste(sprintf("%+.3f", m), collapse = " "), m[1] / m[2], paste(sprintf("%+.3f", mj), collapse = " "), mj[1] / mj[2])) }
lad(c("H", "Hea", "Hea2")); lad(c("Ho", "Hoea", "Hoea2"))
cat(sprintf("Ho - H: root_P50 %+.3f eps, ln J %+.3f eps\n", (el("Ho") - el("H")) / eps, (lj("Ho") - lj("H")) / epsJ))
edges <- readRDS(file.path(S, "rp50/Ho_edges_dry.rds"))
for (s in c("0.02", "-0.02")) { cr <- as.data.frame(readRDS(file.path(Q, sprintf("rp_Ho_%s_dry.rds", s)))$stand$creation)
  # a node is on the open side when the step it starts (or ends) has positive rate on the side facing births
  pos <- cr$rate > 0; at <- function(z) { k <- findInterval(z, cr$start); c(before = pos[max(k - 1, 1)], after = pos[k]) }
  ok <- vapply(edges, function(z) { a <- at(z); a["before"] || a["after"] }, TRUE)
  inside <- vapply(edges, function(z) { a <- at(z); a["before"] && a["after"] }, TRUE)
  cat(sprintf("Ho %s: %d edge nodes; inside an open stretch (both neighbouring steps open) %d (%.0f%%)\n", s, length(edges), sum(inside), 100 * mean(inside))) }
