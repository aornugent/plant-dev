# root_P50's elasticity on a grid, split by birth region and into count and fate parts:
# J = k * sum(w_i nrr_i), with k nearly common to every run (its part is reported).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075; b1 <- 3.529
parts <- function(g) {
  p <- readRDS(file.path(Q, sprintf("rp_%s_0.02_dry.rds", g)))$stand; m <- readRDS(file.path(Q, sprintf("rp_%s_-0.02_dry.rds", g)))$stand
  wp <- head(p$nodes$establishment, -1); wm <- head(m$nodes$establishment, -1); np <- p$nodes$nrr; nm <- m$nodes$nrr
  cp <- wp * np; cm <- wm * nm; Jb <- (sum(cp) + sum(cm)) / 2; b <- p$nodes$birth
  data.frame(b = b, count = (wp - wm) * (np + nm) / 2 / (2 * u) / Jb, fate = (wp + wm) / 2 * (np - nm) / (2 * u) / Jb) |> structure(k = (log(p$J / sum(cp)) - log(m$J / sum(cm))) / (2 * u),
             el = (log(p$J) - log(m$J)) / (2 * u), resid = (log(sum(cp)) - log(sum(cm))) / (2 * u) - sum((cp - cm) / (2 * u) / Jb)) }
summ <- function(g) { d <- parts(g); f <- d$b < b1
  c(founders_count = sum(d$count[f]), founders_fate = sum(d$fate[f]), late_count = sum(d$count[!f]), late_fate = sum(d$fate[!f]),
    k = attr(d, "k"), linearisation = attr(d, "resid"), total = attr(d, "el")) }
G <- c("H", "Hea", "Hea2", "Ho", "Hoea", "Hoea2", "Hoc", "Hocw", "Hoo")
tab <- sapply(G, summ)
cat("elasticity parts (absolute):\n"); print(round(tab, 5))
cat("\nmoves from Ho in eps:\n"); print(round((tab[, c("Hoea", "Hoea2", "Hoc", "Hocw", "Hoo")] - tab[, "Ho"]) / eps, 3))
cat("\nmoves along H's ladder in eps:\n"); print(round(cbind(H_Hea = tab[, "Hea"] - tab[, "H"], Hea_Hea2 = tab[, "Hea2"] - tab[, "Hea"]) / eps, 3))
