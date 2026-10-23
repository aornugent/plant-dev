a <- readRDS("/tmp/front/closed_an.rds"); d <- a$d
d$A <- (d$height / 5.44)^(1 / 0.306)
tb <- (0:108) * 40 / 108
birth <- setNames(tb, 1:109)
# trapezoid weights in birth date
w <- sapply(seq_along(tb), function(i) ((if (i < length(tb)) tb[i + 1] - tb[i] else 0) + (if (i > 1) tb[i] - tb[i - 1] else 0)) / 2)
names(w) <- names(birth)
d$lai <- exp(d$log_density) * w[as.character(d$node)] * d$A
d$lai[!is.finite(d$lai)] <- 0
options(width = 200)
for (tt in c(1.11, 2.22, 3.33, 5, 7.5, 10, 15, 20, 30, 40)) {
  z <- d[abs(d$time - tt) < 0.19, ]
  z <- z[order(-z$height), ]
  tot <- sum(z$lai); f1 <- z$lai[z$node == 1]
  top <- z$height[z$node == 1]; second <- max(z$height[z$node != 1])
  cat(sprintf("age %5.2f  LAI %.2f  founder LAI %.2f (share %.2f)  h1 %.2f  next-tallest %.2f  P1 %.2f  r1 %.3f  mu1 %.3f\n",
              tt, tot, f1, f1 / tot, top, second, z$net_mass_production_dt[z$node == 1], z$r[z$node == 1], z$mu[z$node == 1]))
}
z <- d[d$node == 1, ]; z <- z[order(z$time), ]
# self-thinning: -dlnN/dt against dln(mass)/dt via leaf area
k <- which(z$time >= 2 & z$time <= 20)
fit <- lm(log_density ~ log(A), data = z[k, ])
cat("founder thinning slope dlnN/dlnA (ages 2-20):", coef(fit)[2], "\n")
