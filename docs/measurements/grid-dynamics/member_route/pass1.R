# The reference: every selected member of each invader from its birth to t = 40,
# by Cash-Karp under step-size control at RTOL (spike_lib.R's ck_to), with every
# resident step's end, every birth, every test start and every test step's end
# as a breakpoint. Also chooses the test starts and saves them.
#
# Test starts: each resident step after t = 25 that starts by 38.85 and is at
# least LONG days long (the long dry-spell steps), the step holding 36.28, and the
# first resident step after the last rain before each of those (the dry spell's
# onset, where the pools are fullest).
#
#   PLANT_LIB=$DEV/lib_guard [REC=ld_ruleA] [REGIME=long-drought] [RTOL=1e-8] \
#     [MEMBERS=1,5,...] [LONG=10] [OUT=pass1_ld.rds] Rscript pass1.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
RTOL <- as.numeric(Sys.getenv("RTOL", "1e-8"))
LONG <- as.numeric(Sys.getenv("LONG", "10"))
OUT <- file.path(S, Sys.getenv("OUT", paste0("pass1_", REC, ".rds")))
H_DAYS <- c(7, 15, 22, 26, 31, 38)

days <- t_end - t_beg
long <- which(t_beg > 25 & t_beg <= 38.85 & days * 365 >= LONG)
rain <- rain_record(REGIME)
onset_of <- function(t0) {
  wet <- which(rain[seq_len(floor(t0 * 365))] > 0)
  t_dry <- max(wet) / 365  # day max(wet) - 1 is the last wet day, day max(wet) the first dry one
  t_beg[which(t_beg >= t_dry)[1]]
}
starts <- sort(unique(c(t_beg[long], t_beg[step_of(36.28)], vapply(t_beg[long], onset_of, 0))))
starts <- starts[starts > 25 & starts <= 38.85]
kind <- ifelse(starts %in% t_beg[long], "long step", ifelse(abs(starts - t_beg[step_of(36.28)]) < 1e-12, "36.28", "onset"))
rain_ahead <- vapply(starts, function(t0) sum(rain[ceiling(t0 * 365):floor((t0 + 38 / 365) * 365)]), 0)
start_tab <- data.frame(t0 = starts, kind = kind, k = vapply(starts, step_of, 0L),
                        resident_days = days[vapply(starts, step_of, 0L)] * 365,
                        rain_38d_mm = rain_ahead)
cat(sprintf("%d test starts: %s\n", length(starts), paste(names(table(kind)), table(kind), collapse = ", ")))
outs <- sort(unique(c(starts, as.vector(outer(starts, H_DAYS * DAY, "+")), 40)))

births <- times[MEMBERS]
Y <- lapply(INV, function(x) matrix(0, 7, 0))
saved <- list()
traj <- list()
trace_at <- seq(1, 40, by = 0.25)
stats <- new.env(); stats$accepted <- 0; stats$rejected <- 0
h <- 1e-3
t_clock <- proc.time()[["elapsed"]]
for (k in seq_len(K)) {
  sd <- step_data(k)
  if (k %in% k_intro[MEMBERS]) {
    fld <- field_at(t_beg[k], sd)
    j <- match(k, k_intro)
    for (i in seq_along(INV)) Y[[i]] <- add_member(i, Y[[i]], t_beg[k], j, fld)
    h <- min(h, 1e-3)
  }
  if (all(vapply(Y, ncol, 0) == 0)) next
  cuts <- sort(unique(c(t_beg[k], outs[outs > t_beg[k] & outs < t_end[k]], trace_at[trace_at > t_beg[k] & trace_at < t_end[k]], t_end[k])))
  for (s in seq_len(length(cuts) - 1L)) {
    r <- ck_to(cuts[s], cuts[s + 1L], Y, sd, h, RTOL, stats)
    Y <- r$Y
    h <- r$h
    b <- cuts[s + 1L]
    hit <- which(abs(outs - b) < 1e-12)
    if (length(hit)) saved[[sprintf("%.10f", outs[hit[1]])]] <- Y
    if (any(abs(trace_at - b) < 1e-12)) traj[[sprintf("%.2f", b)]] <- Y
  }
  if (k %% 1000 == 0) {
    cat(sprintf("step %d t %.3f: %d accepted, %d rejected, %d fields, %.0f member ratings, %.0f s\n", k, t_end[k],
                stats$accepted, stats$rejected, counts$fields, counts$members, proc.time()[["elapsed"]] - t_clock))
  }
}
members <- lapply(INV, function(x) data.frame(node = x$node, birth = x$birth))
saveRDS(list(rec = REC, regime = REGIME, rtol = RTOL, invaders = INVADERS, members = members,
             starts = start_tab, h_days = H_DAYS, saved = saved, traj = traj,
             stats = c(accepted = stats$accepted, rejected = stats$rejected, fields = counts$fields,
                       member_ratings = counts$members, secs = proc.time()[["elapsed"]] - t_clock)), OUT)
cat(sprintf("done: %d accepted, %d rejected, %d fields, %.0f member ratings, %.0f s\n", stats$accepted,
            stats$rejected, counts$fields, counts$members, proc.time()[["elapsed"]] - t_clock))
