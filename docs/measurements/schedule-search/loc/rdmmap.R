# rooting_depth_max's elasticity map on dry's G0 (central differences of the J map at +-2%),
# against J's map and against lma's (for a regular quantity's shape, from the same runs' J map).
source("/home/user/plant-dev/harness/schedule/anyscore.R")
u <- 0.02; e <- eps_of("rooting_depth_max")
part <- function(x) { b <- nd(x); own_drop(b, x$dropped) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J }
p <- run("loc_rdm_G0_dry_0.02"); m <- run("loc_rdm_G0_dry_-0.02"); g <- run("loc_G0_dry")
S <- p$node_times; j <- p$dropped; mv <- -(part(p) - part(m)) / (2 * u) / e; J <- part(g) / 0.025
el_c <- (log(p$stand$J) - log(m$stand$J)) / (2 * u); el_s <- g$stand$elasticity[grep("rooting_depth_max", names(g$stand$elasticity))]
cat(sprintf("elasticity: central %.5f, sweep %.5f; map total %+.3f eps (sum|.| %.3f); G0's error vs reference %+.2f eps\n",
  el_c, el_s, sum(mv), sum(abs(mv)), (el_s - reference("dry")["rooting_depth_max"]) / e))
o <- order(-abs(mv)); cs <- cumsum(abs(mv[o])) / sum(abs(mv))
cat(sprintf("panels for 50%%/75%%/90%% of sum|.|: %d / %d / %d of %d\n", which(cs >= .5)[1], which(cs >= .75)[1], which(cs >= .9)[1], length(mv)))
print(round(data.frame(birth = S[j][o[1:12]], move = mv[o[1:12]], J = J[o[1:12]], h_days = (S[j + 1] - S[j - 1])[o[1:12]] / 2 * 365), 3))
g2 <- cut(S[j], c(0, 3.53, 5, 10, 15, 20, 25, 40))
cat("sum move by band:", paste(sprintf("%s %+.3f", levels(g2), tapply(mv, g2, sum)), collapse = "  "), "\n")
cat("sum |move| by band:", paste(sprintf("%s %.3f", levels(g2), tapply(abs(mv), g2, sum)), collapse = "  "), "\n")
cat(sprintf("spearman |move| vs |J map|: %.2f\n", cor(abs(mv), abs(J), method = "spearman")))
