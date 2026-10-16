# Readers for d1.R's records: each listed solve placed in its step, at its fraction
# u of the step, in the (sub)step that integrates its node.
KIND <- c("unsolved", "interior", "boundary-soil", "boundary-crit", "boundary-root-crit",
          "determined", "hydraulic-shutdown", "shade-death", "prescribed", "solver-refused",
          "non-finite-gradient")
JUMP <- c(determined = 5L, `hydraulic-shutdown` = 6L, `boundary-root-crit` = 4L)
AH <- c(0.2, 0.3, 0.6, 1, 0.875)          # RKCK stage fractions, stored stages 0-4
SAMPLE <- c(0, 0.25, 0.5, 0.75, 1)       # the split's field sample fractions
BOUNDARY <- 999999L

# The fraction of each of a split block's substep evaluations, in the order
# integrate_substeps makes them, and the substep each belongs to.
substep_fractions <- function(u) {
  cuts <- c(0, u, 1); f <- c(); g <- c()
  for (c in seq_len(length(cuts) - 1)) {
    from <- cuts[c]; to <- cuts[c + 1]
    if (!(to > from)) next
    if (from > 0) { f <- c(f, from); g <- c(g, c) }
    f <- c(f, from + AH * (to - from)); g <- c(g, rep(c, 5))
  }
  list(u = f, substep = g)
}

load_d1 <- function(file) {
  x <- readRDS(file)
  s <- x$solved
  rows <- s$rows; rows$row <- seq_len(nrow(rows)); rows$nodes <- cumsum(rows$insertion)
  rows$is_step <- rows$insertion == 0 & is.finite(rows$step_size) & rows$step_size > 0
  so <- s$solves; ev <- s$evals; bl <- s$blocks
  so$time <- rows$time[so$row]; ev$time <- rows$time[ev$row]
  so$boundary <- so$node == BOUNDARY | (so$slot <= 7 & so$node >= rows$nodes[so$row])
  nt <- x$node_times
  so$birth <- ifelse(so$boundary, so$time, nt[pmin(so$node + 1, length(nt))])
  # Fractions of every listed solve: stages, end, samples, substeps, sign changes.
  so$u <- NA_real_; so$substep <- NA_integer_
  m <- so$slot <= 4; so$u[m] <- AH[so$slot[m] + 1]; so$substep[m] <- 0L
  m <- so$slot %in% 5:6; so$u[m] <- 1
  m <- so$slot == 7; so$u[m] <- SAMPLE[so$sub[m] + 1]
  key <- paste(bl$row, bl$block)
  ublk <- split(bl$u, key)
  for (k in unique(paste(so$row, so$block)[so$slot %in% 8:9])) {
    u <- ublk[[k]]; sf <- substep_fractions(u)
    m8 <- paste(so$row, so$block) == k & so$slot == 8 & so$node != BOUNDARY
    so$u[m8] <- sf$u[so$sub[m8] + 1]; so$substep[m8] <- sf$substep[so$sub[m8] + 1]
    m9 <- paste(so$row, so$block) == k & so$slot == 9
    so$u[m9] <- u[so$sub[m9] + 1]
  }
  # Count check: a block with m sign changes inside (0, 1) makes 5 + 6m evaluations.
  n8 <- table(paste(ev$row, ev$block)[ev$slot == 8])
  nexp <- vapply(names(n8), function(k) length(substep_fractions(ublk[[k]])$u), 0)
  list(x = x, rows = rows, so = so, ev = ev, bl = bl, block_count_ok = all(n8 == nexp),
       split_nodes = unique(data.frame(row = bl$row, node = bl$node)))
}

# Each (step, node) whose integration meets kind K: the node's evaluations that
# integrate it over that step, in order of u. A split node is integrated by its
# block's substeps; any other by the step's stages. Both start from the first
# stage, which is the previous row's end state (u = 0).
sequences <- function(d, K) {
  so <- d$so; rows <- d$rows
  split_key <- paste(d$split_nodes$row, d$split_nodes$node)
  hit <- so[so$kind == K & !so$boundary, ]
  # Row r's end state is step r+1's first stage.
  cand <- unique(rbind(data.frame(step = hit$row, node = hit$node),
                       data.frame(step = hit$row[hit$slot == 5] + 1, node = hit$node[hit$slot == 5])))
  cand <- cand[cand$step %in% rows$row[rows$is_step], ]
  out <- lapply(seq_len(nrow(cand)), function(i) {
    r <- cand$step[i]; j <- cand$node[i]
    is_split <- paste(r, j) %in% split_key
    first <- so[so$row == r - 1 & so$slot == 5 & so$node == j & !so$boundary, ]
    first$u <- 0; first$substep <- if (is_split) 1L else 0L
    own <- so[so$row == r & so$node == j & !so$boundary &
                (if (is_split) so$slot == 8 else so$slot <= 4), ]
    e <- rbind(first, own)
    e <- e[order(e$u, e$slot, e$sub), ]
    list(step = r, node = j, split = is_split, e = e,
         n_K = sum(e$kind == K), all_K = all(e$kind == K),
         change = any(e$kind == K) && any(e$kind != K),
         change_in_substep = any(tapply(e$kind == K, e$substep, function(v) any(v) && !all(v))),
         others = paste(sort(unique(KIND[e$kind[e$kind != K] + 1])), collapse = ","))
  })
  out[vapply(out, function(o) o$n_K > 0, TRUE)]
}
