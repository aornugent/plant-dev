# Per band: nodes in the committed and check runs, the proxy's error share and shrink,
# and how many open gaps the check leaves unrefined.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R")); R <- AR
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", alg)
for (case in strsplit(Sys.getenv("CASES", "dry-flat dry long-wet episodic"), " ")[[1]]) {
  cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]))
  Sc <- readRDS(file.path(R, sprintf("val_a04t_c_%s.rds", case)))$node_times; Sf <- readRDS(file.path(R, sprintf("val_a04t_f_%s.rds", case)))$node_times
  lf <- approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2)
  per <- function(S) { lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(alg$PW * lf(m)); w[p$shut(m) > 0.5] <- 0; data.frame(m = m, h = hi - lo, e = w * (hi - lo)^3, open = p$shut(m) <= 0.5) }
  a <- per(Sc); b <- per(Sf); br <- c(0, p$b1, 10, 20, 40); ba <- cut(a$m, br); bb <- cut(b$m, br)
  # A gap between consecutive edges is unrefined if it has as many open intervals in both runs.
  ends <- sort(unique(c(0, p$edges, 39.6))); g <- cut(a$m[a$open], ends); gb <- cut(b$m[b$open], ends)
  ta <- table(g); tb <- table(gb); same <- names(ta)[ta > 0 & ta == tb[names(ta)]]
  ga <- cut(a$m, ends); unref <- a$open & as.character(ga) %in% same
  cat(sprintf("\n== %s (b1 %.2f): %d edges; proxy s %.3f\n", case, p$b1, length(p$edges), sum(b$e) / sum(a$e)))
  print(data.frame(band = levels(ba), n_c = as.vector(table(ba[a$open])), n_f = as.vector(table(bb[b$open])),
    share_c = round(tapply(a$e, ba, sum) / sum(a$e), 3), shrink = round(tapply(b$e, bb, sum) / tapply(a$e, ba, sum), 3),
    unrefined_n = as.vector(tapply(unref, ba, sum)), unrefined_share = round(tapply(a$e * unref, ba, sum) / sum(a$e), 3)), row.names = FALSE) }
