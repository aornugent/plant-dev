# strip_status.R: on layout D, each closing edge's strip (the interval that crosses it) by
# what the alternate drop does to it: merged (odd panel), never merged (even panel), or in a
# panel with no interior node; with the pilot's J and establishment in those panels.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
for (cs in c("dry", "long-wet", "episodic-lma")) { D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs))); ea <- edges_all(cs); cl <- ea$b[!ea$opening]
  P <- D$panels; st <- vapply(cl, function(c0) { k <- findInterval(c0, D$breaks); n <- P$n_interior[k]; if (n == 0) "no node" else if (n %% 2 == 0) "never merged" else "merged" }, "")
  k <- findInterval(cl, D$breaks)
  cat(sprintf("%-13s closing edges %d: merged %d, never merged %d, in no-node panels %d | J of their panels: merged %.3f, never %.3f, none %.3f\n", cs, length(cl),
    sum(st == "merged"), sum(st == "never merged"), sum(st == "no node"), sum(P$Jsh[unique(k[st == "merged"])]), sum(P$Jsh[unique(k[st == "never merged"])]), sum(P$Jsh[unique(k[st == "no node"])]))) }
