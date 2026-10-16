# q2_field.R: the founders' field part by channel. J(drop) - J(fine) on the f64 schedule
# with the founders f32 lacks dropped from the field (light, soil or both), and its
# central difference over theta*(1 +- 0.01): each channel's share of the founders'
# f32 -> f64 move in ln J and in the elasticities of lma and a_l1.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
J <- function(n) { f <- file.path(FO, "runs", paste0(n, ".rds")); if (!file.exists(f)) return(NA); readRDS(f)$stand$J }
dl <- log(1.01 / 0.99); res <- list()
for (cs in commandArgs(TRUE)) { Jf <- J(sprintf("fd_%s_guard", cs))
  ch <- sapply(c("LS", "L", "S"), function(c) log(J(sprintf("dr_%s_%s", cs, c)) / Jf) / 0.025)
  cat(sprintf("%s ln J field part (eps): both %+.4f | light %+.4f | soil %+.4f | light + soil %+.4f\n", cs, ch["LS"], ch["L"], ch["S"], ch["L"] + ch["S"]))
  for (tr in c("lma", "a_l1")) { e <- unname(eps_vec(tr))
    d <- sapply(c("L", "S"), function(c) (log(J(sprintf("dr_%s_%s_%s+", cs, c, tr)) / J(sprintf("fd_%s_%s+", cs, tr))) -
                                         log(J(sprintf("dr_%s_%s_%s-", cs, c, tr)) / J(sprintf("fd_%s_%s-", cs, tr)))) / dl / e)
    cat(sprintf("   %-5s field part's elasticity contribution (eps): light %+.3f | soil %+.3f | sum %+.3f\n", tr, d["L"], d["S"], sum(d)))
    res[[paste(cs, tr)]] <- d }
  res[[cs]] <- ch }
saveRDS(res, file.path(FO, "q2_field.rds"))
