# mkends.R D1RDS PIN OUT: PIN's steps with step ends added at the first and last
# Determined transition of each step that holds one, by round4/JT/mkstops.R's
# method: the new boundaries are pinned exactly, and every other step keeps its
# recorded size, input slopes and substep ends. A transition lies between two of a
# node's evaluations over the step (d1_lib.R's sequences: the first stage, then the
# stages or, for a split node, its block's substeps, in order of u) where its kind
# changes into or out of Determined; the end goes midway between them. A substepped
# step's pieces keep its input slope and take its substep ends that fall inside
# them, plus every stage and sample fraction, so they are substepped as it was.
source("/home/user/plant-dev/docs/measurements/kinks/jump-census/d1_lib.R")
a <- commandArgs(TRUE)
d <- load_d1(a[1]); s <- readRDS(a[2])$stand; out <- a[3]
FRAC <- sort(unique(c(AH, SAMPLE[-1])))
rows <- d$rows
step_rows <- which(rows$is_step)
stopifnot(length(step_rows) == length(s$times) - 1, identical(rows$time[step_rows], s$times[-1]))
sq <- sequences(d, JUMP[["determined"]])
cuts <- list()
for (o in sq) {
  e <- o$e; k <- e$kind == JUMP[["determined"]]
  i <- which(diff(k) != 0)
  m <- (e$u[i] + e$u[i + 1]) / 2
  m <- m[m > 0 & m < 1]
  key <- as.character(o$step)
  cuts[[key]] <- c(cuts[[key]], m)
}
cuts <- lapply(cuts, function(v) sort(unique(range(v))))
# Row r of the recording reaches s$times[k + 1], where k is r's place among the steps.
k_of <- match(as.integer(names(cuts)), step_rows)
nt <- c(); sz <- c(); ni <- list(); ns <- list()
tt <- s$times
add <- data.frame()
for (k in seq_along(tt)) {
  ci <- which(k_of + 1 == k)
  if (k == 1 || !length(ci)) {
    nt <- c(nt, tt[k]); sz <- c(sz, s$sizes[k])
    ni[[length(ni) + 1]] <- s$input_slopes[[k]]; ns[[length(ns) + 1]] <- s$substep_ends[[k]]
    next
  }
  f <- cuts[[ci]]; t0 <- tt[k - 1]; h <- tt[k] - t0
  ends <- c(t0 + f * h, tt[k])
  starts <- c(t0, t0 + f * h)
  sub <- length(s$input_slopes[[k]]) > 0
  for (p in seq_along(ends)) {
    nt <- c(nt, ends[p]); sz <- c(sz, ends[p] - starts[p])
    if (sub) {
      hp <- ends[p] - starts[p]
      pe <- (t0 + s$substep_ends[[k]] * h - starts[p]) / hp
      e <- sort(unique(c(FRAC, pe[pe > 1e-12 & pe < 1 - 1e-12])))
      e[length(e)] <- 1
      ni[[length(ni) + 1]] <- s$input_slopes[[k]]; ns[[length(ns) + 1]] <- e
    } else {
      ni[[length(ni) + 1]] <- numeric(0); ns[[length(ns) + 1]] <- numeric(0)
    }
  }
  add <- rbind(add, data.frame(row = as.integer(names(cuts)[ci]), t0 = t0, h_days = h * 365,
                               f = paste(round(f, 3), collapse = ","), substepped = sub))
}
stopifnot(!is.unsorted(nt, strictly = TRUE), length(nt) == length(sz))
saveRDS(list(stand = list(times = nt, sizes = sz, input_slopes = ni, substep_ends = ns), added = add), out)
cat(sprintf("steps holding Determined: %d; split: %d (%d substepped); ends added: %d; steps %d -> %d\n",
            length(cuts), nrow(add), sum(add$substepped), length(nt) - length(tt),
            length(tt) - 1, length(nt) - 1))
