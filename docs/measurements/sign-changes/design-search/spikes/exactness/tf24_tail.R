D <- readRDS("tf24_K_40.rds")
D$err <- D$Kslope - D$Kd
o <- order(-abs(D$err))
cat("share of slope's sum sq error in top 10 / 50 / 200 node-steps:", round(sum(D$err[o[1:10]]^2) / sum(D$err^2), 3),
    round(sum(D$err[o[1:50]]^2) / sum(D$err^2), 3), round(sum(D$err[o[1:200]]^2) / sum(D$err^2), 3), "\n")
rel <- abs(D$err) / pmax(abs(D$Kd), 1e-30)
cat("relative error |Kslope-Kd|/|Kd|: median", signif(median(rel), 3), " 90%", signif(quantile(rel, .9), 3), "\n")
print(data.frame(t = round(D$t[o[1:12]], 4), node = D$node[o[1:12]], h_d = round(D$h[o[1:12]] * 365, 3), ustar = round(D$ustar[o[1:12]], 3),
  roots = D$nroots[o[1:12]], s = signif(D$s[o[1:12]], 3), Kd = signif(D$Kd[o[1:12]], 3), Kslope = signif(D$Kslope[o[1:12]], 3),
  Ke = signif(D$Ke[o[1:12]], 3), P = apply(D[o[1:12], c("P1", "P2", "P3", "P4", "P5", "P6", "Pe")], 1, function(v) paste(signif(v, 2), collapse = " "))))
# without the node-steps whose dense P has two or more roots
s2 <- D$nroots < 2
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2))
cat(sprintf("one root only (n=%d): slope %.3f quartic+end %.3f\n", sum(s2), r(D$Kd[s2], D$Kslope[s2]), r(D$Kd[s2], D$Ke[s2])))
