# P4: theta0's correction applied to theta1's committed run (each on its own a09 grid).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
prs <- list(c("dry", "dry-p50"), c("dry-p50", "dry"), c("long-wet", "wet-adG2"), c("wet-adG2", "long-wet"), c("episodic", "episodic-lma"), c("episodic-lma", "episodic"))
for (pr in prs) { A <- pair(pr[1]); B <- pair(pr[2]); k <- intersect(A$k, B$k)
  corrA <- (A$d / (1 - A$s))[k]; raw <- B$ec[k]; cor <- raw - corrA; own <- B$ec[k] - (B$d / (1 - B$s))[k]
  cr <- crit(raw, corrA)
  cat(sprintf("%-12s -> %-12s raw worst %.2f | corrected by theta0 worst %.2f rms %.3f (own extrap %.2f) | theta0 est as theta1 est: %s | worst corrected at %s\n",
    pr[1], pr[2], max(abs(raw)), max(abs(cor)), sqrt(mean(cor^2)), max(abs(own)), paste(names(cr)[cr], collapse = ""), k[which.max(abs(cor))])) }
