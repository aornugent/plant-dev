# a05_fill whose runs leave out every edge after b = 25. The build sees every edge, so
# spells there keep their own interior nodes, and no shut gap is merged.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", environment())
a05_algorithm <- algorithm
algorithm <- function(ctx) { late <- round(ctx$pilot$edges[ctx$pilot$edges > 25], 10); run0 <- ctx$run
  ctx$run <- function(S, ...) run0(S[!(round(S, 10) %in% late)], ...); a05_algorithm(ctx) }
