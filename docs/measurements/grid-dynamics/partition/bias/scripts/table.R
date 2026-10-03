# This study's whole-run results beside the spike's: J against J*, steps, leaf
# solves (member evaluations) against the monolith's at 3e-5, and the relative
# difference of nodes 1, 2 and 3..6's output against the monolithic run at 3e-5.
#
#   Rscript table.R name1 [name2 ...]   (spike runs in split/out, this study's in partition_bias/out)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
J_STAR <- 12.6687135
m <- readRDS(file.path(D, "split/out/mono_3e-5.rds"))$by_node
cm <- m$weight * m$fecundity * m$patch_density
find <- function(nm) {
  cand <- file.path(D, c("partition_bias/out", "split/out"), paste0(nm, ".rds"))
  cand[file.exists(cand)][1]
}
cat(sprintf("%-24s %10s %7s %9s | %-30s\n", "run", "J-J*", "steps", "leaf/mono", "output vs mono 3e-5: n1 n2 n3-6"))
for (nm in commandArgs(TRUE)) {
  f <- find(nm)
  if (is.na(f)) { cat(nm, "missing\n"); next }
  o <- readRDS(f)
  p <- o$by_node
  c1 <- p$weight * p$fecundity * p$patch_density
  leaf <- if (!is.null(o$counts$members)) o$counts$members else NA
  cat(sprintf("%-24s %+10.2e %7d %9.3f | %+9.2e %+9.2e %+9.2e\n", nm, (o$J - J_STAR) / J_STAR, nrow(o$st),
              leaf / 7063344, c1[1] / cm[1] - 1, c1[2] / cm[2] - 1, sum(c1[3:6]) / sum(cm[3:6]) - 1))
}
