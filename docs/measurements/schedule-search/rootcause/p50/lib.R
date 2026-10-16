# Shared loaders for the root_P50 round: the closing round's lib (references, M, err_run,
# mv_run, fmt) plus this round's run directory, and the founders' runs.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R"))
P5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/p50"
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
rd5 <- function(nm) { for (d in c(file.path(P5, "runs"), file.path(CL, "runs"), file.path(FO, "runs"), ADJ)) { f <- file.path(d, paste0(nm, ".rds")); if (file.exists(f)) return(readRDS(f)) }; stop("no run ", nm) }
KEY <- c("lnJ", "root_P50", "omega", "TF24_cost_scale", "stem_c", "a_l1", "storage_relaxation_offset", "root_c", "a")
key <- function(x) paste(sprintf("%s %+.2f", c("lnJ", "P50", "omega", "cost", "stem_c", "a_l1", "sro", "root_c", "a"), x[KEY]), collapse = " ")
line <- function(lab, x, base = NULL) cat(sprintf("  %-22s M %+.2f rms %.3f | %s\n", lab, onM(x), r2(x), key(x)))
