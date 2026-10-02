# Each split's crossing u_c on the quintic's frozen structure at lma (1 + r)
# and (1 - r) against the base run's: a smooth u_c(lma) moves by opposite
# amounts either side, so the pairs whose two moves do not cancel are where the
# split stops being smooth in lma. Also the locations the regula falsi left
# unconverged.
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
r <- commandArgs(TRUE)[1]; if (is.na(r)) r <- "1e-5"
b <- readRDS(file.path(E, "runs", "slq_1e-4.rds"))
p <- readRDS(file.path(E, "runs", sprintf("sldq_lma_%s.rds", r)))
m <- readRDS(file.path(E, "runs", sprintf("sldq_lma_-%s.rds", r)))
key <- function(d) paste(d$row, d$member)
stopifnot(identical(key(b), key(p)), identical(key(b), key(m)))
d <- data.frame(row = b$row, member = b$member, uc = b$uc, up = p$uc - b$uc, dn = m$uc - b$uc,
                it0 = b$iterations, itp = p$iterations, itm = m$iterations, P0 = b$P0, P1 = b$P1,
                located = paste(p$located, m$located))
d$asym <- abs(d$up + d$dn)
d$scale <- pmax(abs(d$up), abs(d$dn))
cat(sprintf("r %s: %d splits; |u_c move| median %.2g, 99%% %.2g; asymmetry median %.2g, 99%% %.2g, max %.2g\n",
            r, nrow(d), median(d$scale), quantile(d$scale, 0.99), median(d$asym), quantile(d$asym, 0.99), max(d$asym)))
cat(sprintf("unconverged (30 iterations): base %d, + %d, - %d; clamped: + %d, - %d\n",
            sum(d$it0 >= 30), sum(d$itp >= 30), sum(d$itm >= 30), sum(p$located == 0), sum(m$located == 0)))
cat("the least symmetric pairs:\n")
print(format(head(d[order(-d$asym), ], 12), digits = 3), row.names = FALSE)
u <- d[d$it0 >= 30 | d$itp >= 30 | d$itm >= 30, ]
cat(sprintf("\nunconverged pairs: asymmetry median %.2g, max %.2g; |P| left at the base's last iterate unknown, P0/P1 median %.2g/%.2g\n",
            median(u$asym), max(u$asym), median(abs(u$P0)), median(abs(u$P1))))
