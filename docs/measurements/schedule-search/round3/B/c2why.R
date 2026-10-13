# Which quantity fails C2 when dry's committed run loses the 5.64 gap's two edges.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R")); EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", alg)
pe <- pilot_edges("dry"); px <- readRDS(file.path(RUNS, paste0(case_of("dry")$pilot, ".rds")))$stand
p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])); ref <- reference("dry")
xf <- readRDS(file.path(AR, "val_a05t_f_dry.rds")); qf <- quantities(xf)
for (c in c("val_a05t_c", "probe_mg5.5-5.7_10")) { xc <- readRDS(file.path(AR, paste0(c, "_dry.rds"))); qc <- quantities(xc); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  s <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times); ec <- (qc[k] - ref[k]) / e; est <- (qc[k] - qf[k]) / e / (1 - s)
  i <- which(abs(ec) > 0.45); cat(c, "\n"); print(round(rbind(err = ec[i], est = est[i]), 3)) }
