suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
O <- file.path(SP, "refine/s05/epi-adG208")
L <- function(n) qv(readRDS(file.path(O, paste0(n, ".rds")))) / EPS
q0 <- L("level0"); q1 <- L("level1"); q2 <- L("level2"); qr <- L("level0_replay"); q0p <- L("level0_on_level1_steps")
d <- data.frame(q = Q, Dm = qr - q0, D10 = q0 - q1, D10p = q0p - q1, D21 = q1 - q2)
d$r_m0 <- d$Dm / d$D10p; d$r_01 <- d$D10p / d$D21
d <- d[order(-abs(d$D21)), ]; options(width = 200); print(format(d[1:25, ], digits = 2), row.names = FALSE)
