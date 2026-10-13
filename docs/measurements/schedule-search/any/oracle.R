source("lab.R"); source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/lateral/a04_proxy.R")
res <- list()
for (cs in names(CASES)) { p <- CD[[cs]]$pilot
  for (bg in c(80, 90, 100)) for (ly in c(12, 16, 20, 24, 32)) for (k in c(0, 0.2, 0.4)) { BG <<- bg; LAYER <<- ly; K <<- k
    S <- build_graded(p, hfun_of(p)); E <- bandE(cs, S); w <- max(abs(c(feat(cs, S)[1], rowSums(E))))
    res[[length(res) + 1]] <- data.frame(cs, bg, ly, k, cost = cost(cs, S), worst = w) } }
r <- do.call(rbind, res); base <- r[r$bg == 90 & r$ly == 24 & r$k == 0.2, ]; print(base)
for (tw in c(0.7, 0.8, 0.9)) { b <- do.call(rbind, lapply(split(r, r$cs), function(x) { x <- x[x$worst <= tw, ]; x[which.min(x$cost), ] }))
  cat("target", tw, "\n"); print(b); cat("sum cost", sum(b$cost), "vs base", sum(base$cost), "\n") }
