# lib.R: the U round's loaders. The H5 round's layout (h5_sched) and scoring (score_lib.R),
# with runs and schedules read from and written to this round's output directory.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
H5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u"
UOUT <- H5
# Layout U. h5_sched reads the global D as one day; round4/AG/lib.R reuses D for a path.
u_sched <- function(cs, s, ...) { Dp <- D; D <<- 1 / 365; on.exit(D <<- Dp); h5_sched(cs, s, "node1", tcut = 10, ...) }
SK <- c("16" = 1.6, "10" = 1, "06" = 1 / 1.6)
