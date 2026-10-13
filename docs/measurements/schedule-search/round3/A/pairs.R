# Groups scan.rds by schedule and record only, and lists each group's tolerances,
# settings and whether its elasticities are finite.
tab <- readRDS("/home/user/plant-dev/docs/measurements/schedule-search/round3/A/scan.rds")
tab$rec <- sub("\\|.*", "", sub("^[^|]*\\|", "", tab$key))
tab$trait <- sub(".*TRAIT_REL=([^;]*).*", "\\1", tab$key); tab$trait[!grepl("TRAIT_REL", tab$key)] <- "?"
tab$seed <- sapply(strsplit(tab$key, "\\|"), `[`, 3)
tab$env <- sapply(strsplit(tab$key, "\\|"), `[`, 5)
tab$dir <- basename(dirname(dirname(tab$file)))
g <- split(tab, paste(tab$rec, tab$seed, tab$trait, tab$sched))
for (d in g) { if (length(unique(d$tol)) < 2 || !any(d$has_el)) next
  d <- d[order(d$tol), ]
  cat(sprintf("== %s seed %s trait '%s' n %d\n", d$rec[1], d$seed[1], d$trait[1], d$n[1]))
  envs <- unique(d$env)
  for (i in seq_len(nrow(d))) cat(sprintf("  %-34s %-12s tol %-8g el %-5s J %.10f rows %8.0f cpu %6.1f sw %6.1f env#%d\n", d$name[i], d$dir[i], d$tol[i], d$has_el[i], d$J[i], d$rows[i], d$cpu[i], d$sweep_cpu[i], match(d$env[i], envs)))
  for (k in seq_along(envs)) cat(sprintf("    env#%d %s\n", k, substr(gsub("WEIGHT=[^;]*;", "", envs[k]), 1, 160))) }
