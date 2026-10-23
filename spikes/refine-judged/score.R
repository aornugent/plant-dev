# Score each case's two fits against its reference, u429 + (u429 - u215)/3 at 3e-5.
#   PLANT_LIB=... Rscript spikes/refine-judged/score.R OUTDIR RESULTS.rds
source(file.path(Sys.getenv("PLANT_DEV", "."), "spikes/refine-judged/refine_judged.R"))
a <- commandArgs(TRUE); out <- a[1]
cases <- basename(list.dirs(out, recursive = FALSE))
score_case <- function(case) {
  dir <- file.path(out, case); if (!file.exists(file.path(dir, "fits.rds"))) return(NULL)
  f <- readRDS(file.path(dir, "fits.rds")); ref <- NULL
  rdir <- file.path(out, sub("@.*", "", case))
  if (all(file.exists(file.path(rdir, c("u215.rds", "u429.rds"))))) {
    u215 <- all_quantities(readRDS(file.path(rdir, "u215.rds")))
    u429 <- all_quantities(readRDS(file.path(rdir, "u429.rds")))[names(u215)]
    ref <- list(value = u429 + (u429 - u215) / 3, move = (u429 - u215) / 3 / eps_all(names(u215)))
  }
  runs <- lapply(setNames(nm = unique(unlist(lapply(f$fits, `[[`, "runs")))), function(r) readRDS(file.path(dir, paste0(r, ".rds")))$cost)
  lapply(f$fits, function(fit) {
    cost <- Reduce(`+`, lapply(fit$runs, function(r) colSums(runs[[r]][if (r == "first") "forward" else CHARGED[[fit$set]], , drop = FALSE])))
    s <- list(case = case, set = fit$set, status = fit$status, level = fit$level, passes = fit$passes,
              nodes = fit$nodes, runs = length(fit$runs), run_names = fit$runs, cpu = cost[["cpu"]], wall = cost[["wall"]],
              history = fit$history)
    if (!is.null(ref)) {
      n <- names(fit$answer); eps <- eps_all(n)
      err <- (fit$answer - ref$value[n]) / eps      # corrected answer's true error, in eps
      raw <- (fit$run - ref$value[n]) / eps         # the run's own true error
      s$err <- err; s$raw <- raw; s$estimate <- fit$estimate; s$bound <- fit$bound; s$ref_move <- ref$move[n]
      grp <- ifelse(n == "lnJ", "lnJ", ifelse(startsWith(n, "g."), "g", "elasticity"))
      s$by_group <- do.call(rbind, lapply(split(seq_along(n), grp), function(i) data.frame(
        worst_err = max(abs(err[i])), worst_quantity = n[i][which.max(abs(err[i]))],
        worst_raw = max(abs(raw[i])), covered = sum(abs(err[i]) <= fit$bound[i]), of = length(i),
        worst_bound = max(fit$bound[i]), ref_move = max(abs(ref$move[n[i]])))))
    }
    s })
}
res <- unlist(lapply(cases, score_case), recursive = FALSE)
saveRDS(res, a[2])
for (s in res) {
  cat(sprintf("\n%s %s: %s level %d, %d passes, %d nodes, %d runs, cpu %.1f min, wall %.1f min\n", s$case, s$set,
              s$status, s$level, s$passes, s$nodes, s$runs, s$cpu / 60, s$wall / 60))
  if (!is.null(s$by_group)) print(s$by_group, digits = 3)
}

# Every run's quantities and costs, and each case's reference rungs, without the recordings.
runs <- lapply(setNames(nm = cases), function(case) {
  files <- list.files(file.path(out, case), "^(level|u).*\\.rds$", full.names = TRUE)
  lapply(setNames(files, sub("\\.rds$", "", basename(files))), function(f) {
    x <- readRDS(f); list(nodes = length(x$node_times), quantities = all_quantities(x), cost = x$cost) }) })
saveRDS(runs, sub("\\.rds$", "-runs.rds", a[2]))
