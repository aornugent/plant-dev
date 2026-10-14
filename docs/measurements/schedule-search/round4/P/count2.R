source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
tot <- 0; t2 <- c(0, 0, 0)
for (cs in ALL) { S <- sched(cs); r <- c(length(S), length(spell_mid(S, cs)), sapply(c(6, 12, 18), function(d) length(spell_inset(S, cs, d)))); tot <- tot + r
  cat(sprintf("%-13s a09 %3d | mid %3d | inset 6 d %3d, 12 d %3d, 18 d %3d\n", cs, r[1], r[2], r[3], r[4], r[5])) }
cat("all ten c:", tot, "\n")
