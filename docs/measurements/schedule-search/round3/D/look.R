R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
nm <- c("val_a09_c","val_a09s_c","val_a10bug_c","val_a10n1_c","val_a10n2_c","val_a10n1s_c","val_a10n1g_c","val_a10s_c","val_a10_c")
x <- lapply(nm, function(n) { f <- paste0(R, n, "_long-drought.rds"); if (file.exists(f)) readRDS(f) })
names(x) <- nm
for (n in nm) { s <- x[[n]]; if (is.null(s)) {cat(n, "missing\n"); next}
  cat(sprintf("%-14s nodes %d J %.7f steps %d splits %s refusal %s maxel %.1f lib %s\n", n, length(s$node_times), s$stand$J,
    length(s$stand$times), length(s$stand$splits), paste(format(s$refusal), collapse=" "), max(abs(s$stand$elasticity)), basename(s$setting$env["LIB"])))}
E <- sapply(x[!sapply(x,is.null)], function(s) s$stand$elasticity)
print(round(E[order(-apply(abs(E),1,max)),][1:15,],2))
str(x$val_a10s_c$stand$splits)
