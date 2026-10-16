# q2_fd.R: the founders' f32 -> f64 move in an elasticity split into its interpolation
# part (central difference over pinned runs at theta*(1 +- 0.01)) and the rest (field).
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
args <- commandArgs(TRUE); cases <- if (length(args)) args else c("dry", "episodic-lma")
rd <- function(n) readRDS(file.path(FO, "runs", paste0(n, ".rds")))
lat <- function(cs, f) readRDS(file.path(ADJ, sprintf("lat_%s_f%d_l70.rds", cs, f)))
# Interpolation part and fate shape from one f64 stand: relative to J.
parts <- function(s, b1) { n <- s$nodes; m <- length(n$birth); w <- n$establishment[1:m]; f <- n$nrr
  odd <- which(n$birth < b1 - 1e-9 & seq_len(m) %% 2 == 0)   # dropped in f32: 2nd, 4th, ... (1-based)
  A <- sum(w * f); itp <- sum(w[odd] * ((f[odd - 1] + f[odd + 1]) / 2 - f[odd])) / A
  i <- which(n$birth < b1 - 1e-9); g <- log(f[i]); b <- n$birth[i]
  c(itp = itp, lnJ = log(s$J), g0 = (g[9] - g[1]) / (b[9] - b[1]), gmid = (g[33] - g[25]) / (b[33] - b[25])) }
for (cs in cases) { b1 <- pilot_edges(cs)$b1
  L64 <- lat(cs, 64); L32 <- lat(cs, 32)
  # guard: f32's founders are f64's odd-numbered (1-based) nodes
  stopifnot(all(abs(L32$stand$nodes$birth[L32$stand$nodes$birth < b1] - L64$stand$nodes$birth[L64$stand$nodes$birth < b1][c(TRUE, FALSE)]) < 1e-9))
  g <- rd(sprintf("fd_%s_guard", cs))$stand
  cat(sprintf("%s guard: J pinned %.12g stored %.12g (rel %.1e); max |nrr diff| rel %.1e\n", cs, g$J, L64$stand$J, g$J / L64$stand$J - 1,
    max(abs(g$nodes$nrr / L64$stand$nodes$nrr - 1))))
  p0 <- parts(L64$stand, b1)
  cat(sprintf("  interp part (f32 vs f64) %+.3e of J (%.3f eps of lnJ); g' first eighth %.2f, mid %.2f\n", p0["itp"], p0["itp"] / 0.025, p0["g0"], p0["gmid"]))
  for (tr in c("a", "lma", "a_l1")) { fp <- sprintf("fd_%s_%s+", cs, tr); fm <- sprintf("fd_%s_%s-", cs, tr)
    if (!file.exists(file.path(FO, "runs", paste0(fp, ".rds"))) || !file.exists(file.path(FO, "runs", paste0(fm, ".rds")))) next
    pp <- parts(rd(fp)$stand, b1); pm <- parts(rd(fm)$stand, b1); dl <- log(1.01 / 0.99)
    d <- (pp - pm) / dl                       # per unit ln theta
    eps <- eps_vec(tr)
    move <- (quantities(L32)[tr] - quantities(L64)[tr])   # f32 - f64 elasticity
    fdel <- d["lnJ"]; stored <- quantities(L64)[tr]
    cat(sprintf("  %-5s FD elasticity %.4f vs stored %.4f | move f32-f64 %+.4f (%.2f eps) | interp part's derivative %+.4f (%.2f eps) | ratio %.2f | field (rest) %+.2f eps | dg'0/dln %+.3f dg'mid/dln %+.3f\n",
      tr, fdel, stored, move, move / eps, d["itp"], d["itp"] / eps, d["itp"] / move, (move - d["itp"]) / eps, d["g0"], d["gmid"])) } }
