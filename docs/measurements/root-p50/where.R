# root_P50's elasticity moves C -> H and H -> BH on dry, by birth region: central
# differences (+-2%) of each panel's part of J's move, own and field separately.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
source("/home/user/plant-dev/harness/node_parts.R")
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02
r <- function(g, s) readRDS(file.path(Q, sprintf("rp_%s_%s_dry.rds", g, s)))
cr <- readRDS(file.path(Q, "m_th0_f_dry.rds"))$stand$creation; op <- cr$rate > 0.01; rl <- rle(op); e <- cumsum(rl$lengths)
ed <- cr$end[e][-length(e)]; closing <- ed[op[e][-length(e)]]; b1 <- closing[closing > 0][1]
region <- function(b) ifelse(b < b1, "founders", ifelse(vapply(b, function(z) any(abs(z - closing) < 10 / 365), TRUE), "near closing", "other late"))
el <- function(g) (log(r(g, "0.02")$stand$J) - log(r(g, "-0.02")$stand$J)) / (2 * u)
mv <- function(a, b) { f <- function(s) { x <- nodes_of(r(a, s)); y <- nodes_of(r(b, s)); pm <- panel_moves(x, y); J <- sum(x$w * x$offspring)
    data.frame(birth = x$birth, own = (pm$interpolation + pm$establishment) / J, field = pm$field / J) }
  p <- f("0.02"); m <- f("-0.02"); data.frame(birth = p$birth, own = (p$own - m$own) / (2 * u), field = (p$field - m$field) / (2 * u)) }
eps <- 0.01075
cat(sprintf("FD elasticity: C %.4f, H %.4f, BH %.4f | moves C->H %+.4f, H->BH %+.4f (in eps %+.2f, %+.2f; ratio %.2f)\n", el("C"), el("H"), el("BH"),
  el("H") - el("C"), el("BH") - el("H"), (el("H") - el("C")) / eps, (el("BH") - el("H")) / eps, (el("H") - el("C")) / (el("BH") - el("H"))))
a <- mv("C", "H"); b <- mv("H", "BH")
t1 <- sapply(c("own", "field"), function(k) tapply(a[[k]], region(a$birth), sum)) / eps
t2 <- sapply(c("own", "field"), function(k) tapply(b[[k]], region(b$birth), sum)) / eps
cat("C -> H (eps):\n"); print(round(t1, 3)); cat("H -> BH (eps):\n"); print(round(t2, 3)); cat("ratio:\n"); print(round(t1 / t2, 2))
