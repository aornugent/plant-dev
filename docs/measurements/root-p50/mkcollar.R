# Ho plus graded nodes inside each window beside its edge node: closings (Hoc), openings (Hoo).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
ho <- readRDS(file.path(S, "rp50/Ho_dry.rds")); ed <- readRDS(file.path(S, "rp50/Ho_edges_dry.rds"))
cr <- as.data.frame(readRDS(file.path(Q, "rp_Ho_0.02_dry.rds"))$stand$creation); pos <- cr$rate > 0
openat <- function(z) { k <- findInterval(z, cr$start); pos[pmax(k, 1)] }
# a closing node has its window behind it: the nearest shut step within 10 d lies ahead
isclose <- vapply(ed, function(z) { d <- seq(0.05, 10, by = 0.05) / 365
  fa <- which(!vapply(z + d, openat, TRUE))[1]; ba <- which(!vapply(z - d, openat, TRUE))[1]
  if (is.na(ba)) TRUE else if (is.na(fa)) FALSE else fa < ba }, TRUE)
add <- function(z, offs) { y <- z + offs / 365; y[vapply(y, openat, TRUE)] }  # keep only inside the window
cc <- unlist(lapply(ed[isclose], add, offs = -c(0.25, 0.5, 1, 2, 4, 8)))
oo <- unlist(lapply(ed[!isclose], add, offs = c(0.1, 0.25, 0.5, 1, 2, 4, 8)))
hoc <- sort(unique(round(c(ho, cc), 9))); hoo <- sort(unique(round(c(ho, oo), 9)))
saveRDS(hoc, file.path(S, "rp50/Hoc_dry.rds")); saveRDS(hoo, file.path(S, "rp50/Hoo_dry.rds"))
cat(sprintf("closing edges %d, opening %d; Hoc %d nodes (+%d), Hoo %d (+%d)\n", sum(isclose), sum(!isclose), length(hoc), length(hoc) - length(ho), length(hoo), length(hoo) - length(ho)))
