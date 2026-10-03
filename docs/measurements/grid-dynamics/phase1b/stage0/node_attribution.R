# Where DP's J excess sits by node: each node's share of J (weight x fecundity
# x patch density, the driver's by_node) against CK at 1e-8 (J*), for CK and DP
# at each tolerance, summed over birth-time bands.
#   Rscript stage0/node_attribution.R   (from phase1b/)
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
ref <- readRDS(file.path(DEV, "ark/ck_u108_1e-8.rds"))
share <- function(r) with(r$by_node, weight * fecundity * patch_density)
s0 <- share(ref)
k <- ref$J / sum(s0)
runs <- c(ck_1e4 = "events/runs/v0_1e-4.rds", ck_3e5 = "seed/tied_3e-5.rds", ck_1e5 = "rej/tied_1e-5_soil1.rds",
          dp_1e4 = "phase1b/runs/dp_1e-4.rds", dp_3e5 = "phase1b/runs/dp_3e-5.rds", dp_1e5 = "phase1b/runs/dp_1e-5.rds")
bands <- cut(ref$by_node$time, c(-1, 1, 3, 6, 10, 20, 40), labels = c("0-1", "1-3", "3-6", "6-10", "10-20", "20-40"))
cat(sprintf("reference J %.9f; node shares sum to J times %.6g\n", ref$J, 1 / k))
out <- sapply(runs, function(f) {
  r <- readRDS(file.path(DEV, f))
  stopifnot(isTRUE(all.equal(r$by_node$time, ref$by_node$time)))
  tapply((share(r) - s0) * k / ref$J, bands, sum)
})
print(signif(rbind(out, total = colSums(out)), 3))
cat("share of J by band:", paste(sprintf("%s %.3f", levels(bands), tapply(s0, bands, sum) / sum(s0)), collapse = ", "), "\n")
