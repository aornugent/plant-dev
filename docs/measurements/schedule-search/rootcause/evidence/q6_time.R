# q6_time.R: the J window by calendar time on the ten committed runs (dwr omit-one maps with
# node records): T(t) = 1 - sum_j W_j o_j(t) / sum_j W_j o_j(end), o_j the node's survival-
# weighted offspring so far. T at 10/17/20/25 y and the times where T = 0.5, 0.1, 0.01.
SC <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
cases <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2"); out <- list()
for (cs in cases) { x <- readRDS(file.path(SC, "dwr/runs", sprintf("map_o1a_%s.rds", cs))); nr <- x$noderec; m <- length(x$node_times)
  w <- x$stand$nodes$establishment[1:m]; k <- which(nr$names == "offspring_produced_survival_weighted")
  Jt <- sapply(nr$state, function(s) { nn <- (length(s) - 10) / 9; if (nn < 1) return(0); v <- matrix(s[1:(9 * nn)], nrow = 9)[k, ]; sum(w[seq_along(v)] * v) })
  T <- 1 - Jt / tail(Jt, 1); tt <- nr$time
  at <- function(a) approx(tt, T, a)$y; when <- function(p) { i <- which(T <= p)[1]; if (is.na(i)) NA else tt[i] }
  out[[cs]] <- data.frame(case = cs, T10 = at(10), T17 = at(17), T20 = at(20), T25 = at(25), T30 = at(30), t50 = when(0.5), t10 = when(0.1), t01 = when(0.01)) }
tab <- do.call(rbind, out); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(SC, "evidence", "q6_time.rds"))
