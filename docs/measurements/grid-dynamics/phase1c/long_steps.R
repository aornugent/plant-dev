# How many steps of each program exceed a cap, before and after the weight
# starts (the first t with weight > 1), and the first time each cap would bind.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
progs <- c("ld unweighted" = "rej/tied_3e-5_soil1", "ld rule A" = "window/drv/long-drought_rule",
           "wet unweighted" = "window/drv/long-wet_base", "wet rule A" = "window/drv/long-wet_rule",
           "epi unweighted" = "window/drv/episodic_base", "epi rule A" = "window/drv/episodic_rule")
start <- c(ld = 22.50, wet = 22.45, epi = 23.50)
caps <- c(15, 18, 20, 22, 24, 26)
for (k in names(progs)) {
  st <- readRDS(file.path(D, paste0(progs[[k]], ".rds")))$st
  hd <- st$h * 365; t0 <- st$time - st$h; s <- start[[sub(" .*", "", k)]]
  cat(sprintf("%-15s %s\n", k, paste(vapply(caps, function(c) {
    over <- hd > c + 1e-9
    sprintf("%d d: %d before %.1f / %d after, first at %s", c, sum(over & t0 < s), s, sum(over & t0 >= s),
            if (any(over)) sprintf("%.2f", t0[which(over)[1]]) else "-")
  }, ""), collapse = " | ")))
}
