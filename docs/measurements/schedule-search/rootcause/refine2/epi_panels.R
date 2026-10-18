LIFETIME <- 40; source("/home/user/plant-dev/harness/schedule/refine.R")
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
O <- file.path(SP, "refine/s05/epi-adG208")
f1 <- readRDS(file.path(SP, "refine/s1/epi-adG208.rds")); s1 <- f1$schedule
first <- readRDS(file.path(O, "first.rds")); first$establishment <- first$stand$establishment; first$remaining <- first$stand$remaining
tp <- list(storage_relaxation_offset = s1$t_r / 365, a_st3 = exp(1), a_dG2 = 1)
s05 <- schedule_of(first, tp, 0.5); s1b <- schedule_of(first, tp, 1)
for (k in 0:2) cat("level", k, "matches saved:", isTRUE(all.equal(nodes_of(s05, k), sort(readRDS(file.path(O, sprintf("level%d_times.rds", k)))))), "\n")
cat("scale-1 level 0 from first.rds matches fit:", isTRUE(all.equal(nodes_of(s1b, 0), nodes_of(s1, 0))), length(nodes_of(s1, 0)), "\n")
cat("t_r", s1$t_r, " b1", s1$spells$b1, "t50", s1$spells$t50, "t90", s1$spells$t90, "\n")
P <- do.call(rbind, lapply(seq_along(s1$panels), function(i) { p <- s1$panels[[i]]; data.frame(i = i, lo = round(p$lo, 4), hi = round(p$hi, 4), days = round((p$hi - p$lo) * 365, 1), open = s1$spells$shut((p$lo + p$hi) / 2) < 0.5, n1 = p$n) }))
P$n05 <- vapply(s05$panels, `[[`, 0, "n")[seq_len(nrow(P))]
P$lo05 <- round(vapply(s05$panels, `[[`, 0, "lo"), 4)[seq_len(nrow(P))]
options(width = 200); print(P, row.names = FALSE)
saveRDS(list(s05 = s05, s1 = s1), "schedules.rds")
