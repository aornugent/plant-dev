# Reorders queue.txt's pending lines: drops the names in DROP (kept as comments), then puts
# the names in FIRST, in that order, ahead of the other pending lines. Done lines and
# comments keep their places.
#   Rscript reorder.R "drop1,drop2" "first1,first2,..."
a <- commandArgs(TRUE)
drop <- strsplit(a[1], ",")[[1]]
first <- if (length(a) > 1) strsplit(a[2], ",")[[1]] else character()
q <- readLines("queue.txt")
done <- if (file.exists("done.txt")) readLines("done.txt") else character()
name <- function(l) sub(" .*", "", l)
pending <- !grepl("^#", q) & !name(q) %in% done & nzchar(q)
q[pending & name(q) %in% drop] <- paste("# dropped (ck100a not converging):", q[pending & name(q) %in% drop])
pending <- !grepl("^#", q) & !name(q) %in% done & nzchar(q)
p <- q[pending]
p <- c(p[match(first, name(p))][!is.na(match(first, name(p)))], p[!name(p) %in% first])
q <- c(q[!pending], p)
writeLines(q, "queue.new")
file.rename("queue.new", "queue.txt")
cat(name(p), sep = " "); cat("\n")
