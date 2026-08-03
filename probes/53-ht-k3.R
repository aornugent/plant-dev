# The decisive convergence point for the height arm on TF24: 1121 introductions.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE)
r <- run_fixed(a[1], as.logical(as.integer(a[2])), as.integer(a[3]))
print(r, digits = 12)
saveRDS(r, sprintf("/home/user/plant-dev/probes/out/53-%s-%s-k%s.rds", a[1],
                   if (as.integer(a[2])==1) "bd" else "ht", a[3]))
cat("DONE\n")
