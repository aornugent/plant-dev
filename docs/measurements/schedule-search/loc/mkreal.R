# Real runs of an algorithm's two schedules: the committed (c) and its nested check (f),
# built from each case's pilot as the algorithm would. Prints job lines for one.sh.
#   Rscript mkreal.R ALG.R TAG CASE...
source("/home/user/plant-dev/harness/schedule/lattice.R")
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env); tag <- a[2]; L <- file.path(DEV, "schedtest/loc")
for (case in a[-(1:2)]) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  p <- list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, J = px$J, creation = as.data.frame(px$creation),
            nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]), soil = px$soil)
  runs <- list()
  ctx <- list(pilot = p, horizon = 39.6, eps = function(k) rep(1, length(k)),
    run = function(S, gradient = TRUE, drop = NULL) { runs[[length(runs) + 1]] <<- sort(round(S, 10)); q <- c(lnJ = 0); list(q = q, rows = 0, map = NULL) })
  try(env$algorithm(ctx), silent = TRUE)
  wt <- if (!is.null(cs$weight)) cs$weight else cs$rec
  extra <- paste(c(if (cs$trait != "") paste0("TRAIT_REL=", cs$trait), if (cs$set == "pf") "SHARE= SPLIT=0",
                   if (!is.null(cs$seed) && cs$seed != "") paste0("SEED=", cs$seed),
                   sprintf("WEIGHT=%s/window/rule_A/weight_%s.rds", DEV, wt)), collapse = " ")
  for (i in seq_along(runs)) { nm <- sprintf("loc_%s_%s_%s", tag, c("c", "f", "x", "y")[i], case); f <- file.path(L, paste0(nm, ".rds")); saveRDS(runs[[i]], f)
    cat(sprintf("%s %s TIMES=%s %s\n", nm, cs$rec, f, extra)) } }
