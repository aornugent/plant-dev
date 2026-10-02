# The frontier table: J's error against J* and the costs of every run's log, in
# leaf solves (member evaluations, the soil's exact-coupling ones apart),
# uptake_at calls and soil-chain rate evaluations.
#   Rscript frontier.R
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split"
D <- "/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/docs/measurements/grid-dynamics"
J_STAR <- 12.6687135
num <- function(re, x) { m <- regmatches(x, regexpr(re, x, perl = TRUE)); if (length(m)) as.numeric(sub(re, "\\1", m, perl = TRUE)) else NA }
read_log <- function(f, name = sub("\\.log$", "", basename(f))) {
  x <- readLines(f, warn = FALSE)
  x <- x[grepl(": J |member evaluations", x)]
  if (length(x) < 2) return(NULL)
  l1 <- x[1]; l2 <- x[2]
  data.frame(run = name,
             J = num("J ([0-9.]+)", l1),
             steps = num("([0-9]+) accepted,", l1),
             rejected = num("rejected_inaccurate=([0-9]+)", l1) + num("rejected_thrown=([0-9]+)", l1),
             leaf = num("member evaluations ([0-9]+)", l2),
             sub_leaf = { v <- num("\\+ ([0-9]+) in the soil", l2); if (is.na(v)) 0 else v },
             uptake_at = { v <- num("uptake_at ([0-9]+)", l2); if (is.na(v)) 0 else v },
             soil_rates = { v <- num("soil-chain rates ([0-9]+)", l2); if (is.na(v)) 0 else v })
}
logs <- list.files(file.path(S, "logs"), pattern = "\\.log$", full.names = TRUE)
logs <- logs[!grepl("runs\\.log|install|bitcheck", logs)]
tab <- do.call(rbind, lapply(logs, read_log))
docs <- c("mono_1e-5_docs" = "tied_1e-5_soil1.log")
for (n in names(docs)) tab <- rbind(tab, read_log(file.path(D, docs[[n]]), n))
tab$err <- (tab$J - J_STAR) / J_STAR
tab$leaf_vs_mono3e5 <- (tab$leaf + tab$sub_leaf) / 7063344
options(width = 220)
tab <- tab[order(grepl("^mono", tab$run), tab$run), ]
print(tab[, c("run", "J", "err", "steps", "rejected", "leaf", "sub_leaf", "leaf_vs_mono3e5", "uptake_at", "soil_rates")],
      row.names = FALSE, digits = 4)
