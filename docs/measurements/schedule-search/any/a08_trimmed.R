# a07 with the late edges handled as c5t and a06 did: short shut gaps merge before the
# build (a spell whose gaps merge on both sides keeps its start edge), every edge after
# b = 25 stays through the build, so spells there keep their own interior nodes, and is
# then left out of both runs.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a07_trimmed.R", environment())
LATE <- Inf
late_edges <- NULL
a07_algorithm <- algorithm
algorithm <- function(ctx) { late_edges <<- round(ctx$pilot$edges[ctx$pilot$edges > 25], 10); run0 <- ctx$run
  ctx$run <- function(S, ...) run0(S[!(round(S, 10) %in% late_edges)], ...); a07_algorithm(ctx) }
