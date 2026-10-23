a <- readRDS("/tmp/front/closed_an.rds"); s <- a$s
options(width = 200)
print(s[1:10, c("node", "birth", "hmax", "M_end", "fec_end", "share")], digits = 4)
f <- c(live = "/tmp/front/inv_live.rds", p4 = "/tmp/front/inv_1.0001.rds", m4 = "/tmp/front/inv_0.9999.rds",
       p5 = "/tmp/front/inv_1.00001.rds", m5 = "/tmp/front/inv_0.99999.rds")
r <- lapply(f, readRDS)
B <- sapply(r, function(x) x$by_node[[1]])
cat("lnR:", sapply(r, `[[`, "lnR"), "\n")
nt <- r$live$node_times[[1]]
print(cbind(t = nt, B[, 1, drop = FALSE], dln_p4 = log(B[, "p4"] / B[, "live"]), dln_m4 = log(B[, "m4"] / B[, "live"]),
            dln_p5 = log(B[, "p5"] / B[, "live"]), dln_m5 = log(B[, "m5"] / B[, "live"])), digits = 4)
