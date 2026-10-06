# Diagnostic D3 (prereg.txt), read from the walk's log on a plant built with
# d3_print.patch: each correction the walk added, and its storage against the
# invader's own.
#   PLANT_DBG_SPLIT=1 PLANT_LIB=... SPLIT=1 OUT=print.rds Rscript walk_x2.R > print.log
#   Rscript d3_corrections.R print.log
x <- readLines(commandArgs(TRUE)[1])
d <- x[startsWith(x, "DBG ")]
m <- do.call(rbind, strsplit(sub("^DBG ", "", d), " "))
z <- data.frame(t = as.numeric(m[, 1]), block = as.integer(m[, 2]),
                q = as.integer(m[, 5]), v = as.numeric(m[, 6]),
                before = as.numeric(m[, 7]), run_end = as.numeric(m[, 8]),
                carried = as.numeric(m[, 9]))
names <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
           "storage", "offspring_sw", "interval_establishment",
           "interval_establishment_moment")
z$name <- names[z$q + 1]
cat(sprintf("%d corrections over %d split steps, years %.4f to %.4f\n", nrow(z),
            length(unique(z$t)), min(z$t), max(z$t)))
s <- z[z$name == "storage", ]
cat(sprintf("storage: %d corrections, %d leaving it below zero; carried / own from %.4g to %.4g\n",
            nrow(s), sum(s$carried < 0), min(s$carried / s$v), max(s$carried / s$v)))
last <- z[z$t == max(z$t) & z$name %in% c("height", "mortality", "storage"), ]
cat(sprintf("the last split step before the failure, year %.6f:\n", max(z$t)))
print(last[, c("block", "name", "v", "before", "run_end", "carried")], digits = 5,
      row.names = FALSE)
