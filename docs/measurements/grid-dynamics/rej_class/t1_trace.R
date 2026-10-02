# One rain onset's attempts in pics_3e-5, attempt by attempt: the soil state, the
# rain, h|lambda|/beta, the coupled and the chain-alone ratio. Picks the onset
# knot whose first-day rejection has the median coupled ratio.
#   nice -n 10 Rscript DEV/rej_class/t1_trace.R
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
x <- readRDS(file.path(O, "t1_pics_3e-5.rds"))
b <- readRDS(file.path(O, "t1_rejected_pics_3e-5.rds"))
on <- b[b$after == "starts", ]
pick <- on[order(abs(on$ratio - median(on$ratio)))[1], ]
z <- x[x$knot == pick$knot & x$since <= 1.2, ]
z$h <- z$h * 365
print(z[, c("t0", "h", "since", "n_since", "try", "rej", "ratio", "layer", "chain", "chain_layer", "x_soil",
            "theta1", "theta2", "theta3", "rain_t0", "rain_t1")], digits = 3, row.names = FALSE)
