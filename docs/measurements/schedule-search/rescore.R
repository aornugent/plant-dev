# Rescore every candidate of both generations under scorer v3 with 20 noise draws.
suppressMessages(source("/home/user/plant-dev/harness/schedule/surrogate.R"))
fs <- list.files("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search", "^(cand|c)[_0-9].*\\.R$|^ladder\\.R$", recursive = TRUE, full.names = TRUE)
res <- do.call(rbind, lapply(fs, function(f) { env <- new.env(); ok <- tryCatch({ sys.source(f, env); TRUE }, error = function(e) FALSE)
  if (!ok || !is.function(env$algorithm)) return(NULL); alg <- function(ctx) env$algorithm(ctx)
  r <- lapply(1:20, function(d) { STRESS <<- d; tryCatch(evaluate(alg), error = function(e) NULL) }); STRESS <<- 0
  r <- Filter(Negate(is.null), r); if (!length(r)) return(NULL)
  data.frame(file = sub(".*/search/", "", f), feasible = sum(sapply(r, `[[`, "feasible")), of = length(r), T_max = max(sapply(r, `[[`, "T")), T_med = median(sapply(r, `[[`, "T"))) }))
res <- res[order(-res$feasible, res$T_max), ]; saveRDS(res, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/rescore_v3.rds")
print(head(res, 15), row.names = FALSE); cat(nrow(res), "candidates\n")
