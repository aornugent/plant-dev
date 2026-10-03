# Rebuilds queue.txt's pending tail: inserts the lines of a file after the line whose
# name is AFTER (driver runs) and, optionally, the frozen lines after FZ_AFTER.
#   Rscript requeue.R lines.txt AFTER [FZ_AFTER]
a <- commandArgs(TRUE)
q <- readLines("queue.txt")
new <- readLines(a[1])
name <- function(l) sub(" .*", "", l)
drv <- new[!grepl("^fz_", new)]
fz <- new[grepl("^fz_", new)]
q <- q[!name(q) %in% name(new)]
at <- match(a[2], name(q))
stopifnot(!is.na(at))
q <- append(q, drv, after = at)
if (length(a) > 2 && length(fz)) {
  at2 <- match(a[3], name(q))
  stopifnot(!is.na(at2))
  q <- append(q, fz, after = at2)
} else q <- append(q, fz, after = at + length(drv))
writeLines(q, "queue.new")
file.rename("queue.new", "queue.txt")
cat(name(q), sep = "\n")
