# Each node's share of J in the monolithic run, and each partitioned run's
# relative difference by node, for the first few nodes.
#   Rscript bynode.R
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out"
m <- readRDS(file.path(S, "mono_3e-5.rds"))$by_node
cm <- m$weight * m$fecundity * m$patch_density
cat("mono_3e-5: J share of nodes 1..6:", sprintf("%.4f", (cm / sum(cm))[1:6]), "\n")
cat("node times 1..6:", sprintf("%.3f", m$time[1:6]), "\n")
cat("weights 1..6:", sprintf("%.4g", m$weight[1:6]), "\n")
cat("fecundity 1..6:", sprintf("%.4g", m$fecundity[1:6]), "\n")
for (f in c("stagelind_1e-4_s3e-5", "stagelind_3e-5_s3e-5", "stagelind_1e-5_s3e-5",
            "stagelind_3e-6_s3e-5", "stagelind_1e-6_s3e-5", "exactx_3e-5_s3e-5",
            "exactx_1e-5_s3e-5", "pc1d_3e-5_s3e-5", "pc1d_1e-5_s3e-5", "mono_1e-4", "mono_1e-3")) {
  p <- readRDS(file.path(S, paste0(f, ".rds")))$by_node
  c1 <- p$weight * p$fecundity * p$patch_density
  cat(sprintf("%-22s dJ/J %+.3e | rel diff by node 1..6: %s | weight diffs 1..3: %s\n", f, sum(c1 - cm) / sum(cm),
              paste(sprintf("%+.2e", (c1 / cm - 1)[1:6]), collapse = " "),
              paste(sprintf("%+.1e", (p$weight / m$weight - 1)[1:3]), collapse = " ")))
}
