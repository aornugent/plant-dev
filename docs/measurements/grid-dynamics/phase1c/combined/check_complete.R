# Which runs in combined/full finished, and which phases each holds.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined/full"
for (f in list.files(C, "\\.rds$", full.names = TRUE)) {
  x <- readRDS(f)
  cat(sprintf("%-26s finished %-5s phases %s; failures %d\n", basename(f), !is.null(x$finished),
              paste(names(x$phases), collapse = ","), length(x$failures)))
}
