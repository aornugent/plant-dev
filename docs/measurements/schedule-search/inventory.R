# Inventory of stored runs: per directory, how many, which records, with gradients, maps, nodes.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
fs <- list.files(D, pattern = "\\.rds$", recursive = TRUE, full.names = TRUE)
fs <- fs[grepl("/runs/", fs)]
info <- do.call(rbind, lapply(fs, function(f) { x <- tryCatch(readRDS(f), error = function(e) NULL)
  if (!is.list(x) || is.null(x$stand)) return(NULL)
  st <- x$setting; rec <- if (!is.null(st$regime)) st$regime else if (!is.null(st$scen)) st$scen else NA
  data.frame(dir = sub(paste0(D, "/"), "", dirname(dirname(f))), rec = as.character(rec)[1],
    nodes = length(x$node_times), grad = !is.null(x$stand$elasticity), map = !is.null(x$light),
    trait = if (!is.null(st$env)) as.character(st$env[["TRAIT_REL"]]) else NA,
    cpu = if (!is.null(x$stand$cpu)) x$stand$cpu else NA, sweep = if (!is.null(x$sweep_cpu)) x$sweep_cpu else NA, rows = if (!is.null(x$stand$rows)) x$stand$rows else NA) }))
saveRDS(info, file.path(D, "schedtest/p1/inventory.rds"))
cat("runs:", nrow(info), " with gradients:", sum(info$grad), " with maps:", sum(info$map), "\n")
print(table(info$dir, info$grad)); print(table(info$rec, useNA = "ifany"))
g <- info[!is.na(info$cpu) & !is.na(info$rows) & info$rows > 0, ]
cat(sprintf("forward cpu per 1M rows: median %.0f s (n %d); sweep / forward cpu: median %.2f\n", median(g$cpu / g$rows * 1e6), nrow(g), median(g$sweep / g$cpu, na.rm = TRUE)))
