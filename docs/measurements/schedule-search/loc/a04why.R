# Why a04's non-nested check under-reads dry without season: per quantity, the real
# shrink err_f/err_c against the pilot proxy's, for a04 at 1e-4 and c05_graded at 3e-5.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); R <- AR; case <- Sys.getenv("CASE", "dry-flat")
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", alg)
cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]))
x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
k0 <- intersect(names(x), names(y)); ref <- extrap(x[k0], y[k0])
for (tag in c("a04t", "c5g")) { xc <- readRDS(file.path(R, sprintf("val_%s_c_%s.rds", tag, case))); xf <- readRDS(file.path(R, sprintf("val_%s_f_%s.rds", tag, case)))
  qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- ec - ef
  s <- if (tag == "c5g") 0.25 else alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  cat(sprintf("\n== %s: %d and %d nodes, proxy s = %.3f, ref's own estimate up to %.2f\n", tag, length(xc$node_times), length(xf$node_times), s,
              max(abs((y[k] - x[k]) / 3 / eps_vec(k)))))
  o <- order(-abs(ec)); tb <- data.frame(q = k, err_c = ec, err_f = ef, s_real = ef / ec, est = d / (1 - s), ratio = d / (1 - s) / ec, refmove = (y[k] - x[k]) / 3 / e)[o, ]
  print(head(tb[abs(tb$err_c) > 0.2, ], 20), digits = 3, row.names = FALSE) }
