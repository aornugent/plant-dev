# q6_window.R: the pilot's J window by birth date, R(b) = share of J from recruits born after
# b, on the 18 pilots and the episodic runs at shorter patch lifetimes. For the builders'
# absolute ages (10, 17, 20, 25) the share R takes there per pilot, and for one share per
# age (the bank's median) the birth date each pilot would get instead.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
Rb <- function(px, life = 40) { g <- seq(0, life, length.out = 20001); gm <- head(g, -1) + diff(g)[1] / 2; d <- jdens(px, gm)
  cs <- rev(cumsum(rev(d$J))); list(b = gm, R = cs / cs[1], E = rev(cumsum(rev(d$E))) / sum(d$E)) }
AGES <- c(10, 17, 20, 25); rows <- list(); curves <- list()
for (cs in c(BANK, HELD)) { px <- pilot_run(cs); z <- Rb(px); curves[[cs]] <- z
  rows[[cs]] <- data.frame(case = cs, t(setNames(approx(z$b, log10(pmax(z$R, 1e-300)), AGES)$y, paste0("log10R_", AGES))), b1 = pilot_of(cs)$b1) }
tab <- do.call(rbind, rows); bank <- tab[tab$case %in% BANK, ]
thr <- sapply(AGES, function(a) median(bank[[paste0("log10R_", a)]])); names(thr) <- AGES
cat("bank median log10 R at each age:\n"); print(round(thr, 2))
for (a in AGES) tab[[paste0("b_for_", a)]] <- sapply(tab$case, function(cs) { z <- curves[[cs]]; y <- log10(pmax(z$R, 1e-300)); i <- which(y < thr[as.character(a)])[1]; if (is.na(i)) NA else z$b[i] })
options(width = 220); print(format(tab, digits = 3), row.names = FALSE)
RC <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
for (L in c(9, 10, 11, 12, 14, 17, 20)) { x <- readRDS(file.path(RC, sprintf("rc_life%g_episodic.rds", L))); z <- Rb(x$stand, L); y <- log10(pmax(z$R, 1e-300))
  bb <- sapply(AGES, function(a) { i <- which(y < thr[as.character(a)])[1]; if (is.na(i)) NA else z$b[i] })
  q <- sapply(c(0.5, 0.9, 0.99), function(p) z$b[which(1 - z$R >= p)[1]])
  cat(sprintf("episodic, lifetime %4.1f: J %.3g | b for the shares of 10/17/20/25: %s | J quantiles 50/90/99%%: %s\n", L, x$stand$J,
    paste(sprintf("%.1f", bb), collapse = " / "), paste(sprintf("%.2f", q), collapse = " / "))) }
z <- curves[["episodic"]]; q <- sapply(c(0.5, 0.9, 0.99), function(p) z$b[which(1 - z$R >= p)[1]])
cat(sprintf("episodic, lifetime 40 (pilot): J quantiles 50/90/99%%: %s\n", paste(sprintf("%.2f", q), collapse = " / ")))
saveRDS(list(tab = tab, thr = thr), file.path(SC, "evidence", "q6_window.rds"))
