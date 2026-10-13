# Q2: per-node elasticity maps from map pairs at theta (1 +- u), against J's map at theta.
# dE_j = (m_j(+) - m_j(-)) / (2u): the move of the elasticity were node j removed.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
parts <- function(f) { y <- readRDS(file.path(AR, paste0(f, ".rds"))); S <- y$node_times; j <- y$dropped
  nn <- y$stand$nodes; m <- min(length(nn$establishment), length(nn$nrr))
  b <- data.frame(birth = nn$birth[1:m], w = nn$establishment[1:m], offspring = nn$nrr[1:m] * vapply(nn$birth[1:m], patches$density, 0))
  l <- (b$birth[j] - b$birth[j - 1]) / (b$birth[j + 1] - b$birth[j - 1])
  own <- -b$w[j] * (b$offspring[j] - (1 - l) * b$offspring[j - 1] - l * b$offspring[j + 1]) / sum(b$w * b$offspring)
  data.frame(birth = S[j], h1 = S[j] - S[j - 1], h2 = S[j + 1] - S[j], own = own, light = colSums(y$light) / y$stand$J, soil = colSums(y$soil) / y$stand$J) }
sets <- list(c("map_e215", "map_e215_lma", "lma", "episodic", "0.01", "+", "-"), c("map_e215", "map_e215_a_dG2", "a_dG2", "episodic", "0.01", "+", "-"),
  c("map_ld215", "map_ld215_lma", "lma", "long-drought", "0.01", "+", "-"), c("map_ld215", "map_ld215_a_dG2", "a_dG2", "long-drought", "0.01", "+", "-"),
  c(NA, "rpmap_BHlate", "root_P50", "dry", "0.02", "_0.02", "_-0.02"), c(NA, "rpmap_BH2late", "root_P50", "dry", "0.02", "_0.02", "_-0.02"), c(NA, "rpmap_Hoea", "root_P50", "dry", "0.02", "_0.02", "_-0.02"))
ET <- list(dry = edge_table("dry"), episodic = edge_table("episodic"), `long-drought` = edge_table("long-drought"))
all <- list()
for (s in sets) { u <- as.numeric(s[5]); P <- parts(paste0(s[2], s[6])); Mn <- parts(paste0(s[2], s[7]))
  Z <- if (!is.na(s[1])) parts(s[1]) else { Z <- P; Z[, 4:6] <- (P[, 4:6] + Mn[, 4:6]) / 2; Z }
  stopifnot(all(abs(P$birth - Mn$birth) < 1e-9))
  m0 <- (Z$own + Z$light + Z$soil) / EPS_J; mag <- (abs(Z$own) + abs(Z$light) + abs(Z$soil)) / EPS_J; mag2 <- (abs(Z$own) + abs(Z$light + Z$soil)) / EPS_J
  eE <- eps_of(s[3]); dE <- ((P$own + P$light + P$soil) - (Mn$own + Mn$light + Mn$soil)) / (2 * u) / eE
  isE <- vapply(Z$birth, function(b) min(abs(ET[[s[4]]]$e - b)) < 1e-6, TRUE)
  D <- data.frame(set = paste(s[2], s[3]), case = s[4], birth = Z$birth, edge = isE, m = m0, mag = mag, mag2 = mag2, dE = dE, own = Z$own / EPS_J, fld = (Z$light + Z$soil) / EPS_J)
  all[[length(all) + 1]] <- D
  k <- D$birth < 25 & D$mag > 1e-3
  cat(sprintf("%-26s eps %.3f n %d (edges %d) | spearman(|dE|,|m|) %.2f (|dE|,mag) %.2f | sum|dE| %.3f vs |sum dE| %.3f; sum|m| %.3f | ratio |dE|/|m| q50 %.2f q90 %.2f q99 %.1f ; |dE|/mag q50 %.2f q90 %.2f q99 %.2f max %.2f\n",
    paste(s[2], s[3]), eE, sum(k), sum(k & D$edge), cor(abs(D$dE[k]), abs(D$m[k]), method = "spearman"), cor(abs(D$dE[k]), D$mag[k], method = "spearman"),
    sum(abs(D$dE)), abs(sum(D$dE)), sum(abs(D$m)), quantile(abs(D$dE[k] / D$m[k]), .5), quantile(abs(D$dE[k] / D$m[k]), .9), quantile(abs(D$dE[k] / D$m[k]), .99),
    quantile(abs(D$dE[k]) / D$mag[k], .5), quantile(abs(D$dE[k]) / D$mag[k], .9), quantile(abs(D$dE[k]) / D$mag[k], .99), max(abs(D$dE[k]) / D$mag[k]))) }
A <- do.call(rbind, all); saveRDS(A, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_elmaps.rds")
cat("\nedges only (rpmap root_P50, dry):\n"); z <- A[A$edge & A$birth < 25 & A$mag > 1e-4, ]
print(table(z$set)); if (nrow(z)) cat(sprintf("|dE|/|m| q50 %.2f q90 %.2f q99 %.1f; |dE|/mag q50 %.2f q90 %.2f max %.2f\n", quantile(abs(z$dE / z$m), .5), quantile(abs(z$dE / z$m), .9), quantile(abs(z$dE / z$m), .99), quantile(abs(z$dE) / z$mag, .5), quantile(abs(z$dE) / z$mag, .9), max(abs(z$dE) / z$mag)))
cat("\nelasticity moves of nodes whose J move is tiny (|m| < 0.02 eps):\n")
for (st in unique(A$set)) { z <- A[A$set == st & A$birth < 25, ]; t <- abs(z$m) < 0.02
  cat(sprintf("%-26s n tiny %d: max |dE| %.3f, sum |dE| %.3f (all nodes sum |dE| %.3f) | tiny-J nodes with |dE| > 0.02: %d\n", st, sum(t), max(abs(z$dE[t])), sum(abs(z$dE[t])), sum(abs(z$dE)), sum(abs(z$dE[t]) > 0.02))) }
