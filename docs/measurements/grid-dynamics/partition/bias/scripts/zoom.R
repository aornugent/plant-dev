# The where_time table between two times, every common time: where node 1's
# mortality difference jumps, and the reference's own mortality there.
#   Rscript zoom.R table.rds t0 t1 [every]
args <- commandArgs(TRUE)
tab <- readRDS(args[1])
t0 <- as.numeric(args[2]); t1 <- as.numeric(args[3])
every <- if (length(args) > 3) as.integer(args[4]) else 1L
x <- tab[tab$t >= t0 & tab$t <= t1, ]
x <- x[seq(1, nrow(x), by = every), ]
options(width = 250)
print(signif(x[, c("t", "M", "n1_mort", "n1_mortref", "n2_mort", "n3_mort", "n1_stor", "n3_stor", "n1_off",
                   "n1_h", "soil_1", "soil_2", "soil_3", "soil_4", "soil_5")], 3), row.names = FALSE)
