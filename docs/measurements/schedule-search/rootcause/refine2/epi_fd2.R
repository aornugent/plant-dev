E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/epi"
d <- readRDS(file.path(E, "fd_integrand.rds")); S <- readRDS(file.path(E, "schedules.rds"))$s05
pl <- vapply(S$panels, `[[`, 0, "lo"); ph <- vapply(S$panels, `[[`, 0, "hi"); pn <- vapply(S$panels, `[[`, 0, "n")
d$panel <- vapply(d$b, function(x) max(which(pl <= x + 1e-9)), 0)
out <- list()
for (i in which(pn >= 1)) { k <- which(d$panel == i | (abs(d$b - ph[i]) < 1e-9)); k <- sort(unique(k)); if (length(k) < 4) next
  y <- d$rel[k]; x <- d$b[k]; s2 <- abs(diff(diff(y))); m <- median(s2)
  j <- which.max(s2)
  out[[length(out) + 1]] <- data.frame(lo = round(pl[i], 3), hi = round(ph[i], 3), n0 = pn[i], nodes = length(k), rel_lo = round(min(y), 2), rel_hi = round(max(y), 2),
    max_d2 = signif(max(s2), 2), med_d2 = signif(m, 2), ratio = round(max(s2) / m, 1), at = round(x[j + 1], 3), days_to_end = round((ph[i] - x[j + 1]) * 365)) }
options(width = 200); print(do.call(rbind, out), row.names = FALSE)
k <- d$b > 7.98 & d$b < 9.8; print(format(data.frame(b = round(d$b[k], 3), rel = round(d$rel[k], 3), nrr = round(d$nrr[k], 3)), digits = 4), row.names = FALSE)
