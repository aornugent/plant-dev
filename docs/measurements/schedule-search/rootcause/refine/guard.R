# guard.R: the uniform builder at k = 1 reproduces E6's check schedule on all eighteen cases;
# the regions of each S1 (intervals, nodes one refinement adds, rows it adds on S1's steps).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
for (cs in c(BANK, HELD)) { cr <- case_of_refine(cs); u1 <- sort(un_sched(cs, 1))
  same <- length(u1) == length(cr$S1) && max(abs(u1 - cr$S1)) < 1e-9
  reg <- interval_regions(cr$S1, cr$edges, cr$b1); x1 <- e6_runs(cs)$x1
  add <- vapply(REGIONS, function(g) length(refine_nodes(cr$S1, g, cr$edges, cr$b1)), 0)
  ra <- vapply(REGIONS, function(g) rows_added(refine_nodes(cr$S1, g, cr$edges, cr$b1), x1$stand$times) / x1$stand$rows, 0)
  cat(sprintf("%-14s check identical %s | n %d | intervals %s | +nodes %s | +rows %s\n", cs, same, length(cr$S1),
    paste(names(table(reg)), table(reg), sep = ":", collapse = " "), paste(REGIONS, add, sep = ":", collapse = " "), paste(sprintf("%.2f", ra), collapse = " "))) }
