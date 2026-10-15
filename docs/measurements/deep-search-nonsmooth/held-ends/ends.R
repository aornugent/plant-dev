# ends.R: the stop ends of JT8_ins_3e-4_stop and each end's root set, from its log.
# Sourced; defines stop_ends() -> data.frame (row index k, time, mode, cutting node and
# direction, how it was identified) with attr "roots": the root set of each end's
# attempted step (end id, node, direction, root time).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
JT8 <- file.path(S, "JT_out/JT8_ins_3e-4_stop.rds")
JT8LOG <- file.path(S, "adjmap/logs/JT8_ins_3e-4_stop.log")
HMIN <- 1e-6

# Every JTROOT line of a log: attempted step (t0, h), node, root time, direction.
read_roots <- function(f) {
  L <- grep("^JTROOT", readLines(f), value = TRUE)
  x <- do.call(rbind, lapply(strsplit(L, " +"), function(s) as.numeric(s[c(3, 5, 7, 9, 11)])))
  data.frame(t0 = x[, 1], h = x[, 2], node = x[, 3], u = x[, 4],
             t = x[, 1] + x[, 4] * x[, 2], dir = sign(x[, 5]))
}

stop_ends <- function(log = JT8LOG, pin = JT8) {
  tt <- readRDS(pin)$stand$times
  L <- readLines(log)
  is_root <- grepl("^JTROOT", L); is_cut <- grepl("^JTCUT", L)
  # Each cut's root set: the JTROOT lines of the same attempted step just before it.
  ends <- NULL; roots <- NULL
  for (i in which(is_cut)) {
    v <- strsplit(L[i], " +")[[1]]
    t0 <- as.numeric(v[3]); h <- as.numeric(v[5]); u <- as.numeric(v[7]); mode <- v[9]
    if (u * h <= HMIN) next
    back <- i - 1
    while (back >= 1 && is_root[back]) back <- back - 1
    r <- do.call(rbind, lapply(strsplit(L[(back + 1):(i - 1)], " +"), function(s) as.numeric(s[c(3, 5, 7, 9, 11)])))
    r <- r[abs(r[, 1] - t0) < 1e-10 & abs(r[, 2] / h - 1) < 1e-7 & r[, 4] > 1e-6 & r[, 4] < 1 - 1e-6, , drop = FALSE]
    tc <- t0 + u * h
    k <- which.min(abs(tt - tc))
    exact <- abs(tt[k] - tc) < 1e-8 && abs(tt[k - 1] - t0) < 2e-10
    near <- abs(tt[k] - tc) < 1e-3 * h
    cutter <- which.min(abs(r[, 4] - u))
    id <- length(ends) + 1
    ends[[id]] <- data.frame(id = id, k = k, time = tt[k], tcut = tc, t0 = t0, h = h, mode = mode,
                             how = if (exact) "exact" else if (near) "near" else "held",
                             node = r[cutter, 3], dir = sign(r[cutter, 5]), nroots = nrow(r))
    roots[[id]] <- data.frame(id = id, node = r[, 3], dir = sign(r[, 5]), t = t0 + r[, 4] * h)
  }
  e <- do.call(rbind, ends)
  # A cut whose retake did not land is either re-cut on the retried step (that cut's row
  # is exact) or left no end; neither is an end of its own.
  e$how[e$how == "near" & e$k %in% e$k[e$how == "exact"]] <- "held"
  attr(e, "roots") <- do.call(rbind, roots)
  e
}
