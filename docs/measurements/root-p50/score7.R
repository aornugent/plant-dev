# Round 7: root_P50 and ln J on Ho with graded nodes beside closings (Hoc) or openings (Hoo).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075; epsJ <- 0.025
J <- function(g, s) readRDS(file.path(Q, sprintf("rp_%s_%s_dry.rds", g, s)))$stand$J
el <- function(g) (log(J(g, "0.02")) - log(J(g, "-0.02"))) / (2 * u)
lj <- function(g) (log(J(g, "0.02")) + log(J(g, "-0.02"))) / 2
x <- el("Ho") + 2 * (el("Hoea") - el("Ho"))
cat(sprintf("first-order limit of Ho's ladder %.5f (%+.3f eps from Ho)\n", x, (x - el("Ho")) / eps))
for (g in c("Hoea", "Hoea2", "Hoc", "Hoo", "Hocw", "Hocd")) cat(sprintf("%-6s root_P50 %.5f: from Ho %+.3f eps | ln J from Ho %+.3f eps\n", g, el(g), (el(g) - el("Ho")) / eps, (lj(g) - lj("Ho")) / epsJ))
