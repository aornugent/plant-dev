# Shared loaders for agent P: a case's a09 schedules, the pilot's edges, and runs.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R"))
SCH <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/loc"
POUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/P_out"
sched <- function(case, side = "c") readRDS(file.path(SCH, sprintf("loc_a09_%s_%s.rds", side, case)))
# Nodes of S that are pilot edges (within tol years).
is_edge <- function(S, edges, tol = 1e-6) vapply(S, function(s) any(abs(edges - s) < tol), TRUE)
# Per interval of S, against a case's pilot creation record: open and shut days, the
# establishment (integral of the creation rate, years), and the shut days lying between
# the interval's establishing part and each of its nodes.
creation_of <- function(case) as.data.frame(readRDS(file.path(RUNS, paste0(case_of(case)$pilot, ".rds")))$stand$creation)
anatomy <- function(S, case, cr = creation_of(case), thr = 0.01) {
  S <- sort(S); lo <- S[-length(S)]; hi <- S[-1]
  # fine grid of the creation rate
  g <- seq(0, max(S), by = 0.25 / 365); r <- cr$rate[pmax(1, findInterval(g, cr$start))]; op <- r > thr
  k <- findInterval(g, S, rightmost.closed = TRUE); k[k < 1 | k > length(lo)] <- NA
  do.call(rbind, lapply(seq_along(lo), function(i) { z <- which(k == i); if (!length(z)) return(data.frame(lo = lo[i], hi = hi[i], open = 0, shut = 0, E = 0, gap_lo = NA, gap_hi = NA, u = NA))
    o <- op[z]; E <- sum(r[z]) * 0.25 / 365
    u <- if (E > 0) sum(r[z] * (g[z] - lo[i])) * 0.25 / 365 / E / (hi[i] - lo[i]) else NA
    data.frame(lo = lo[i], hi = hi[i], open = sum(o) / 4, shut = sum(!o) / 4, E = E,
      gap_lo = if (any(o)) (which(o)[1] - 1) / 4 else NA, gap_hi = if (any(o)) (length(o) - tail(which(o), 1)) / 4 else NA, u = u) }))
}
# Exposure of a schedule to shut time inside establishing intervals, from anatomy():
# Xg = sum E * (shut days between the establishing part and a node) / 365, years^2;
# Xs = establishment in intervals more than half shut (slivers), years.
exposure <- function(A, cap = 1e9) { m <- A$E > 0 & A$open > 0
  c(Xg = sum(A$E[m] * (pmin(A$gap_lo[m], cap) + pmin(A$gap_hi[m], cap)) / 365), Xs = sum(A$E[m & A$shut > A$open]),
    n_mixed = sum(m & A$shut > 0.5)) }
proxy <- function(case, S) { a <- alg; a$proxy_err(pilot_of(case), sort(S)) }
# The pilot's edges before 25 with their kind and the gap and spell beside each (days).
edge_table <- function(case) { cr <- creation_of(case); op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  ed <- cr$end[e][-length(e)]; closing <- op[e][-length(e)]
  # lengths of the runs either side of each edge
  st <- c(0, cr$end[e]); len <- diff(st) * 365; before <- len[-length(len)]; after <- len[-1]
  k <- ed > 0 & ed < 25
  data.frame(b = ed[k], opening = !closing[k], gap = ifelse(closing[k], after[k], before[k]), spell = ifelse(closing[k], before[k], after[k])) }
# Move every edge node of S (before 25) d days into its gap (out) or its spell (in), at most
# frac of the gap or spell, keeping the node count.
shift_edges <- function(S, case, d, dir = c("out", "in"), frac = 0.45) { dir <- match.arg(dir); et <- edge_table(case)
  sgn <- ifelse(et$opening, -1, 1) * (if (dir == "out") 1 else -1)
  room <- if (dir == "out") et$gap else et$spell; mv <- sgn * pmin(d, frac * room) / 365
  i <- match(round(et$b, 8), round(S, 8)); stopifnot(!anyNA(i)); S[i] <- S[i] + mv
  S <- sort(S); stopifnot(all(diff(S) > 1e-7)); S }
# Each spell with both edges in S (after b1, before 25): its edge-to-edge segments replaced
# by their midpoints, so the spell keeps its spacing and loses one node.
spell_mid <- function(S, case) { et <- edge_table(case); o <- et$b[et$opening]; S <- sort(S); keep <- rep(TRUE, length(S)); add <- c()
  for (a in o) { cc <- et$b[!et$opening & et$b > a]; if (!length(cc)) next; c1 <- min(cc)
    i <- which(S >= a - 1e-9 & S <= c1 + 1e-9); if (abs(S[i[1]] - a) > 1e-8 || abs(tail(S[i], 1) - c1) > 1e-8) next
    keep[i] <- FALSE; add <- c(add, (S[i][-length(i)] + S[i][-1]) / 2) }
  sort(c(S[keep], add)) }
# Each spell with both edges in S (after b1, before 25): nodes from d days inside one edge to
# d days inside the other, at no more than the spell's own spacing; one node at the centre
# of a spell shorter than 2d.
spell_inset <- function(S, case, d = 12) { et <- edge_table(case); o <- et$b[et$opening]; S <- sort(S); keep <- rep(TRUE, length(S)); add <- c(); d <- d / 365
  for (a in o) { cc <- et$b[!et$opening & et$b > a]; if (!length(cc)) next; c1 <- min(cc)
    i <- which(S >= a - 1e-9 & S <= c1 + 1e-9); if (abs(S[i[1]] - a) > 1e-8 || abs(tail(S[i], 1) - c1) > 1e-8) next
    L <- c1 - a; h <- L / (length(i) - 1); keep[i] <- FALSE
    add <- c(add, if (L <= 2 * d) (a + c1) / 2 else seq(a + d, c1 - d, length.out = ceiling((L - 2 * d) / h - 1e-9) + 1)) }
  sort(c(S[keep], add)) }
