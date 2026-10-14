# same.R A.rds B.rds: whether two runs' J, times, sizes and substep ends agree bit for bit.
a <- readRDS(commandArgs(TRUE)[1])$stand; b <- readRDS(commandArgs(TRUE)[2])$stand
for (k in c("J", "times", "sizes", "substep_ends", "input_slopes"))
  cat(sprintf("%-13s identical %s\n", k, identical(a[[k]], b[[k]])))
cat(sprintf("J %.15g vs %.15g; steps %d vs %d\n", a$J, b$J, length(a$times), length(b$times)))
