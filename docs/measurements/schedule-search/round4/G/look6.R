# look6.R: which steps answer to the tolerance? Same schedule at two tolerances (a09 vs a09p),
# steps per age band, split into steps ending on a knot and the rest.
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
br <- c(0, 2, 5, 10, 20, 25, 30, 35, 40)
kn <- function(x) { reg <- x$setting$regime; seed <- x$setting$seed; scen <- sprintf("%s, seed %d", reg, seed)
  RAIN_SPECS[[scen]] <<- modifyList(RAIN_SPECS[[reg]], list(seed = seed)); active_knots(scen) }
for (tag in c("a09p", "a10p", "a09hp")) for (cs in c("dry", "episodic", "long-wet", "dry-flat", "ld-102", "long-drought")) for (cf in c("c")) {
  f1 <- file.path(AR, sprintf("val_a09_%s_%s.rds", cf, cs)); f2 <- file.path(AR, sprintf("val_%s_%s_%s.rds", tag, cf, cs))
  if (tag != "a09p") f1 <- file.path(AR, sprintf("val_%s_%s_%s.rds", sub("p$", "", tag), cf, cs))
  if (!file.exists(f1) || !file.exists(f2)) next
  a <- readRDS(f1); b <- readRDS(f2); if (!isTRUE(all.equal(a$node_times, b$node_times))) { cat(tag, cs, "different schedules\n"); next }
  k <- kn(a)
  one <- function(x) { te <- x$stand$times[-1]; onk <- vapply(te, function(s) min(abs(k - s)) < 1e-9, TRUE); bd <- cut(te, br, right = FALSE)
    rbind(knot = tapply(onk, bd, sum), free = tapply(!onk, bd, sum)) }
  A <- one(a); B <- one(b)
  cat(sprintf("%-6s %-13s tol %.0e -> %.0e  share %s/%s  steps %d -> %d (%.2f) rows %.2f\n", tag, cs, a$setting$tol, b$setting$tol, a$setting$env["SHARE"], b$setting$env["SHARE"],
    length(a$stand$times), length(b$stand$times), length(b$stand$times) / length(a$stand$times), b$stand$rows / a$stand$rows))
  cat("   free steps ratio by band:", sprintf("%.2f", B["free", ] / A["free", ]), "\n")
  cat("   free steps/yr at 1e-4:   ", sprintf("%5.1f", A["free", ] / diff(br)), "\n")
  cat("   knot steps/yr:           ", sprintf("%5.1f", A["knot", ] / diff(br)), "\n") }
