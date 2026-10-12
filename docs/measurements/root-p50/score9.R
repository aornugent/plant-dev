# Round 9: the map's split of root_P50's elasticity move Hoea -> Ho into own and field
# parts, the field by channel, age band after birth and position against closings.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
R <- file.path(dirname(A), "rp50"); u <- 0.02; e <- 0.01075
mp <- run("rpmap_Hoea_0.02"); mm <- run("rpmap_Hoea_-0.02"); fp <- run("rpfwd_Ho_0.02"); fm <- run("rpfwd_Ho_-0.02")
meas <- ((log(fp$stand$J) - log(fm$stand$J)) - (log(mp$stand$J) - log(mm$stand$J))) / (2 * u)
part <- function(x) { b <- nd(x); JnP <- sum(b$w * b$offspring)
  list(own = own_drop(b, x$dropped) / JnP, light = x$light / x$stand$J, soil = x$soil / x$stand$J, birth = b$birth[x$dropped]) }
p <- part(mp); m <- part(mm); d <- function(a, b) (a - b) / (2 * u) / e
own <- d(p$own, m$own); light <- d(p$light, m$light); soil <- d(p$soil, m$soil)
cat(sprintf("measured el(Ho) - el(Hoea) on the map build: %+.3f eps\n", meas / e))
cat(sprintf("map: own %+.3f, field %+.3f (light %+.3f, soil %+.3f), total %+.3f eps\n",
  sum(own), sum(light) + sum(soil), sum(light), sum(soil), sum(own) + sum(light) + sum(soil)))
bands <- c(paste0("<", mp$bands), paste0(">", tail(mp$bands, 1)))
cat("field by age band after birth (light, soil):\n"); print(round(rbind(light = rowSums(light), soil = rowSums(soil)), 3) |> `colnames<-`(bands))
# position of each dropped node against the closings of Ho's run
cr <- as.data.frame(readRDS(file.path(dirname(A), "placed2/runs/rp_Ho_0.02_dry.rds"))$stand$creation); pos <- cr$rate > 0
k <- which(diff(pos) != 0); cl <- cr$end[k][pos[k]]; op <- cr$end[k][!pos[k]]
toc <- vapply(p$birth, function(z) { x <- cl[cl >= z] - z; if (length(x)) min(x) * 365 else Inf }, 1)
sinceo <- vapply(p$birth, function(z) { x <- z - op[op <= z]; if (length(x)) min(x) * 365 else Inf }, 1)
f <- colSums(light) + colSums(soil)
g <- cut(toc, c(-1, 32, 90, 1e9), labels = c("<=32 d before a closing", "32-90 d", ">90 d"))
cat("\nfield and own by the dropped node's distance to the next closing:\n")
print(round(rbind(nodes = table(g), field = tapply(f, g, sum), soil = tapply(colSums(soil), g, sum), own = tapply(own, g, sum)), 3))
yr <- cut(p$birth, c(0, 10, 20, 30, 40)); cat("\nby birth decade:\n"); print(round(rbind(nodes = table(yr), field = tapply(f, yr, sum), own = tapply(own, yr, sum)), 3))
o <- order(-abs(f))[1:10]; cat("\nlargest field parts:\n"); print(round(data.frame(b = p$birth[o], to_closing_d = toc[o], since_opening_d = sinceo[o], field = f[o], soil = colSums(soil)[o], own = own[o]), 3))
