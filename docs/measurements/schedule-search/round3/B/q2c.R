# Q2 against the merge probes: the removed edges' own map parts (|own| + |field|, from the
# ref maps, rescaled to the probe base's geometry) against each probe's largest elasticity move.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
X <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds"); M <- X$M
P <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_probes.rds")
for (nm in names(P)) { cs <- strsplit(nm, " ")[[1]][2]; if (!(cs %in% c("dry", "long-drought"))) next
  seg <- open_segs(cs); S0 <- sort(readRDS(file.path(LOC, sprintf("loc_a04_c_%s.rds", cs)))); rm0 <- P[[nm]]$rm
  z <- M[M$case == cs, ]; mag <- 0; m <- 0; cov <- 0
  for (b in rm0) { i <- which(abs(z$birth - b) < 1e-6); k <- match(round(b, 9), round(S0, 9)); if (!length(i) || is.na(k)) next
    Gm <- vapply(i, function(r) Eopen(z$birth[r] - z$h1[r], z$birth[r] + z$h2[r], seg) - Eopen(z$birth[r] - z$h1[r], z$birth[r], seg) - Eopen(z$birth[r], z$birth[r] + z$h2[r], seg), 0)
    G0 <- Eopen(S0[k - 1], S0[k + 1], seg) - Eopen(S0[k - 1], b, seg) - Eopen(b, S0[k + 1], seg); f <- median(G0 / Gm)
    own <- median(z$own[i]); fl <- median(z$m[i] - z$own[i]); mag <- mag + f * (abs(own) + abs(fl)); m <- m + f * (own + fl); cov <- cov + 1 }
  mv <- P[[nm]]$mv; cat(sprintf("%-28s covered %d/%d | map sum m %+.4f, sum(|own|+|field|) %.4f | measured lnJ %+.4f, max elas %.2f -> ratio max elas / map mag %.0f\n",
    nm, cov, length(rm0), m, mag, mv["lnJ"], max(abs(mv[-1])), max(abs(mv[-1])) / mag)) }
