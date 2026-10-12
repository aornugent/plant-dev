# Does J's per-interval drop map rank the intervals that carry root_P50's elasticity error?
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
R <- file.path(dirname(A), "rp50"); u <- 0.02; e <- 0.01075; eJ <- 0.025
part <- function(x) { b <- nd(x); own_drop(b, x$dropped) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J }
p <- run("rpmap_BHlate_0.02"); m <- run("rpmap_BHlate_-0.02")
b <- nd(p)$birth[p$dropped]; h <- readRDS(file.path(R, "H_dry.rds")); i <- findInterval(b, h)
J <- tapply((part(p) + part(m)) / 2 / eJ, i, sum); el <- tapply(-(part(p) - part(m)) / (2 * u) / e, i, sum)
d <- data.frame(b0 = h[as.integer(names(J))], J = as.numeric(J), el = as.numeric(el))
cat(sprintf("intervals %d; spearman |J| vs |el| %.2f; pearson J vs el %.2f\n", nrow(d), cor(abs(d$J), abs(d$el), method = "spearman"), cor(d$J, d$el)))
o <- order(-abs(d$el)); k <- ceiling(nrow(d) / 4)
cat(sprintf("top quarter by |el| holds %.0f%% of sum|el|; J's top quarter holds %.0f%% of sum|el|\n",
  100 * sum(abs(d$el[o[1:k]])) / sum(abs(d$el)), 100 * sum(abs(d$el[order(-abs(d$J))[1:k]])) / sum(abs(d$el))))
cat(sprintf("share of sum|el| by birth band: %s\n", paste(sprintf("%s %.0f%%", levels(cut(d$b0, c(0, 3, 10, 20, 40))), 100 * tapply(abs(d$el), cut(d$b0, c(0, 3, 10, 20, 40)), sum) / sum(abs(d$el))), collapse = ", ")))
cat(sprintf("share of sum|J| by birth band: %s\n", paste(sprintf("%.0f%%", 100 * tapply(abs(d$J), cut(d$b0, c(0, 3, 10, 20, 40)), sum) / sum(abs(d$J))), collapse = ", ")))
z <- d[abs(d$el) > 1e-6 | abs(d$J) > 1e-6, ]; k <- ceiling(nrow(z) / 4); o <- order(-abs(z$el))
cat(sprintf("nonzero intervals %d (birth %.1f-%.1f); spearman |J| vs |el| %.2f\n", nrow(z), min(z$b0), max(z$b0), cor(abs(z$J), abs(z$el), method = "spearman")))
cat(sprintf("top quarter by |el| holds %.0f%% of sum|el|; J's top quarter holds %.0f%%; |J|>median picks %.0f%%\n",
  100 * sum(abs(z$el[o[1:k]])) / sum(abs(z$el)), 100 * sum(abs(z$el[order(-abs(z$J))[1:k]])) / sum(abs(z$el)), 100 * sum(abs(z$el[abs(z$J) > median(abs(z$J))])) / sum(abs(z$el))))
cat(sprintf("sum|el| %.2f eps, |sum el| %.2f; sum|J| %.2f eps, |sum J| %.2f\n", sum(abs(z$el)), abs(sum(z$el)), sum(abs(z$J)), abs(sum(z$J))))
