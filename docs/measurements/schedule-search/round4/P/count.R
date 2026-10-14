# Nodes each rule saves on a09's committed (c) and check (f) schedules, all ten cases.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
tot <- c(0, 0, 0, 0)
for (cs in ALL) { r <- sapply(c("c", "f"), function(sd) { S <- sched(cs, sd); M <- spell_mid(S, cs); c(length(S), length(M), sum(is_edge(S, pilot_of(cs)$edges))) })
  life <- sapply(c("c", "f"), function(sd) { S <- sched(cs, sd); M <- spell_mid(S, cs); c(sum(39.6 - S), sum(39.6 - M)) })
  tot <- tot + c(r[1, 1], r[2, 1], r[1, 2], r[2, 2])
  cat(sprintf("%-13s c %3d -> %3d (-%2.0f%%, life -%2.0f%%), edges %3d | f %3d -> %3d (-%2.0f%%)\n", cs, r[1, 1], r[2, 1], 100 * (1 - r[2, 1] / r[1, 1]), 100 * (1 - life[2, 1] / life[1, 1]), r[3, 1], r[1, 2], r[2, 2], 100 * (1 - r[2, 2] / r[1, 2]))) }
cat(sprintf("all ten: c %d -> %d, f %d -> %d\n", tot[1], tot[2], tot[3], tot[4]))
