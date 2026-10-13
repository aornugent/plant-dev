# Rows saved on a09's committed schedules (training five) by thinning rules, from the
# scorer's rows model, and T predicted for "thin the committed run, keep a09's check":
# T = C(check) + 3 C(thinned) on a coarse commit (real a09 costs scaled by the rows ratio).
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
merge_rule <- function(cs, S, G = 10, FROM = 0, TO = 25, SPELLS = 1) { pe <- pilot_edges(cs); e <- sort(round(pe$edges, 10))
  m <- (head(e, -1) + e[-1]) / 2; gap <- pe$shut(m) > 0.5 & diff(e) * 365 < G & m >= FROM & m < TO
  drop <- unique(c(e[-length(e)][gap], e[-1][gap]))
  if (SPELLS == 1) { k <- which(gap); both <- k[(k + 2) %in% k]; drop <- setdiff(drop, e[both + 1]) }
  x <- S[!(round(S, 10) %in% drop)]; cap <- function(b) if (b < pe$b1) pe$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
  for (j in which(gap)) { c0 <- m[j]; i <- findInterval(c0, x); if (i >= 1 && i < length(x) && x[i + 1] - x[i] > cap(c0)) x <- sort(c(x, c0)) }
  x }
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/"
rules <- list(`G10 SPELLS=1, b<25` = function(cs, S) merge_rule(cs, S), `G10 SPELLS=1, 10<b<25` = function(cs, S) merge_rule(cs, S, FROM = 10),
  `G10 SPELLS=2, 10<b<25` = function(cs, S) merge_rule(cs, S, FROM = 10, SPELLS = 2),
  `greedy J-map (0.005/0.05)` = function(cs, S) readRDS(sprintf("%sB_thin_%s_0.005_0.05.rds", P, cs)),
  `greedy J-map, b>10 only` = function(cs, S) { T <- readRDS(sprintf("%sB_thin_%s_0.005_0.05.rds", P, cs)); r <- setdiff(round(S, 10), round(T, 10)); S[!(round(S, 10) %in% r[r > 10])] })
Ta <- 0; Tn <- setNames(rep(0, length(rules)), names(rules))
for (cs in names(CASES)) { cd <- prepare(cs); co <- coef(cd$rowsfit); S <- sort(readRDS(file.path(LOC, sprintf("loc_a09_c_%s.rds", cs))))
  rows <- function(x) co[1] * length(x) + co[2] * sum(H - x)
  xc <- readRDS(file.path(AR, sprintf("val_a09_c_%s.rds", cs))); xf <- readRDS(file.path(AR, sprintf("val_a09_f_%s.rds", cs)))
  Cc <- run_cost(xc$stand$rows, TRUE); Cf <- run_cost(xf$stand$rows, TRUE); fine <- cs == "episodic-lma"; T0 <- Cc + Cf + 2 * (if (fine) Cf else Cc); Ta <- Ta + T0
  line <- sprintf("%-13s a09 T %5.0f (C %4.0f, check %4.0f%s)", cs, T0, Cc, Cf, if (fine) ", fine" else "")
  for (r in names(rules)) { x <- rules[[r]](cs, S); f <- rows(x) / rows(S); T1 <- if (fine) T0 else Cf + 3 * Cc * f; Tn[r] <- Tn[r] + T1
    line <- paste0(line, sprintf(" | %s: -%.1f%% rows", r, 100 * (1 - f))) }
  cat(line, "\n") }
cat(sprintf("\na09 training T (from real runs) %.0f\n", Ta)); for (r in names(rules)) cat(sprintf("  %-28s T %.0f (%.1f%%), lma not thinned\n", r, Tn[r], 100 * (Tn[r] / Ta - 1)))
