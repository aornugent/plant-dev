# own_dp.R: the own part of layout D' (every edge a breakpoint, even interval counts) against
# layout D, with each one's alternate-drop estimate, on the five model cases.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/own_model.R")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout_dp.R", echo = FALSE, local = new.env())
src <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout_dp.R", src, toplevel.env = environment())
for (cs in names(REFS)) { M <- model_of(cs); p <- pilot_of(cs); px <- pilot_run(cs); h <- alg$hfun_of(p); ea <- edges_all(cs, px)
  D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs))); Dp <- src$layout_Dp(cs, 1, p, px, h); Dp2 <- src$layout_Dp(cs, 2, p, px, h)
  brk <- round(sort(unique(c(0, ea$b))), 10); inter <- setdiff(round(Dp$S, 10), brk)
  # alternate drop of D': within each spell panel, its 1st, 3rd, ... interior node
  pid <- findInterval(inter, brk); dr <- unlist(lapply(split(inter, pid), function(x) x[seq(1, length(x), by = 2)]))
  e <- own(M, Dp$S); est <- (own(M, setdiff(round(Dp$S, 10), dr)) - e) / 3; e2 <- own(M, Dp2$S)
  eD <- own(M, D$S); estD <- (own(M, setdiff(round(D$S, 10), D$drop)) - eD) / 3
  cat(sprintf("%-12s D': %3d nodes, own %+.4f, drop est %+.4f (read %.2f), own(rho0)/own(2rho0) %.2f | D: %3d nodes, own %+.4f, read %.2f\n", cs, length(Dp$S), e, est, est / e, e / e2, length(D$S), eD, estD / eD)) }
