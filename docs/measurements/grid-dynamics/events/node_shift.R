# Where the split's move of J lives: each node's share of J (weight x
# fecundity x patch density x S_D x birth rate) with and without the split, on
# the 1e-4 grid with the crossing steps cut into n (rp_hn against sp_hn).
#   Rscript node_shift.R [n]
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
n <- commandArgs(TRUE)[1]; if (is.na(n)) n <- "1"
a <- readRDS(file.path(E, "runs", sprintf("rp_h%s.rds", n)))
b <- readRDS(file.path(E, "runs", sprintf("sp_h%s.rds", n)))
share <- function(x) { d <- x$by_node; d$weight * d$fecundity * d$patch_density }
sa <- share(a); sb <- share(b)
d <- data.frame(node = seq_along(sa), birth = a$by_node$time, plain = sa / sum(sa), move = (sb - sa) / sum(sa),
                rel = sb / sa - 1)
cat(sprintf("J plain %.12g, split %.12g: %+.4g relative\n", a$J, b$J, b$J / a$J - 1))
o <- d[order(-abs(d$move)), ]
cat("nodes by their part of the move (move and share relative to plain J):\n")
print(format(head(o, 12), digits = 4), row.names = FALSE)
cat(sprintf("born before 3.6: %+.4g of the move; after: %+.4g\n",
            sum(d$move[d$birth < 3.6]), sum(d$move[d$birth >= 3.6])))
