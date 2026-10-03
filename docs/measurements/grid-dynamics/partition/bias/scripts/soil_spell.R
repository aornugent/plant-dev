# The top layers' moisture inside one dry spell, every run against the tol 1e-7
# reference: at each run's step ends in [t0, t1] (one leg, so no introduction
# inside), the relative difference per layer, summarised by its most negative
# value and its value at the step end nearest tm.
#
#   Rscript soil_spell.R t0 t1 tm
args <- as.numeric(commandArgs(TRUE))
t0 <- args[1]; t1 <- args[2]; tm <- args[3]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
ref <- readRDS(file.path(D, "ark", "ck_u108_1e-7.rds"))$st
w <- ref$time >= t0 - 0.02 & ref$time <= t1 + 0.02
fr <- lapply(1:5, function(l) splinefun(ref$time[w], ref[[paste0("soil_", l)]][w], method = "fmm"))
runs <- c(file.path(D, "split", "out", c(
  "mono_1e-3.rds", "mono_1e-4.rds", "mono_3e-5.rds",
  "held_3e-5_s3e-5.rds", "held_1e-6_s3e-5.rds",
  "stagelind_1e-4_s3e-5.rds", "stagelind_3e-5_s3e-5.rds", "stagelind_1e-5_s3e-5.rds",
  "stagelind_3e-6_s3e-5.rds", "stagelind_1e-6_s3e-5.rds", "stagelind_3e-5_s1e-6.rds",
  "exactx_3e-5_s3e-5.rds", "exactx_1e-5_s3e-5.rds", "pc1d_3e-5_s3e-5.rds", "pc1d_1e-5_s3e-5.rds",
  "pc2_3e-5_s3e-5.rds")),
  list.files(file.path(D, "partition_bias", "out"), pattern = "^(full|rec|fix).*[0-9]\\.rds$", full.names = TRUE))
cat(sprintf("soil relative to the reference in [%g, %g]; 'at' is the step end nearest %g\n", t0, t1, tm))
for (f in runs) {
  if (!file.exists(f)) next
  st <- readRDS(f)$st
  i <- which(st$time >= t0 & st$time <= t1)
  if (!length(i)) next
  d <- sapply(1:5, function(l) (st[[paste0("soil_", l)]][i] - fr[[l]](st$time[i])) / fr[[l]](st$time[i]))
  k <- which.min(abs(st$time[i] - tm))
  cat(sprintf("%-28s steps %3d  min %s | at %.3f %s\n", sub("\\.rds$", "", basename(f)), length(i),
              paste(sprintf("%+.1e", apply(d, 2, min)[1:3]), collapse = " "), st$time[i][k],
              paste(sprintf("%+.1e", d[k, 1:3]), collapse = " ")))
}
