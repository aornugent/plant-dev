# The pools under DP and CK at 1e-4, from the driver's STAGE_LOG and
# ATTEMPT_LOG (runs sl_ck_1e-4, sl_dp_1e-4): (1) stage states holding a
# negative pool, and at what h / tau_s and pool drain h (-dS/dt) / S at the
# step's start; (2) raises and non-finite error ratios; (3) where the
# rejections and rows go, by how fast the fastest pool drains at the start, by
# wet or dry interval, and by time.
#   Rscript stage_pools.R   (from phase1b/)
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/runs"
TAU_S <- 7 / 365
rd <- function(m) {
  s <- readRDS(file.path(R, sprintf("stg_%s_1e-4.rds", m)))
  a <- readRDS(file.path(R, sprintf("att_%s_1e-4.rds", m)))
  stopifnot(nrow(a) == nrow(s$att), isTRUE(all.equal(a$t0, s$att$t0)), isTRUE(all.equal(a$h, s$att$h)))
  s$att$stage_fill_min <- s$att$fill_min
  d <- cbind(a, s$att[, c("h_tau", "drain_max", "empty_start", "wet", "neg_stages", "neg_members", "stage_fill_min",
                          "raised_at", "raised_neg", "raised_soil")])
  d$outcome <- ifelse(d$thrown == 1, "thrown", ifelse(d$rejected == 1, "rejected", "accepted"))
  list(att = d, neg = s$neg)
}
x <- list(ck = rd("ck"), dp = rd("dp"))
cat("== (1) stage states with a member's storage below zero (stages 2-6 and the end, 7), 1e-4\n")
for (m in names(x)) {
  d <- x[[m]]$att; n <- x[[m]]$neg
  hit <- d$neg_stages > 0
  cat(sprintf(" %s: %d attempts; %d stage states with a negative pool in %d attempts (%.2f%% of attempts), %d member-stages, %d members\n",
              toupper(m), nrow(d), sum(d$neg_stages), sum(hit), 100 * mean(hit), sum(d$neg_members),
              if (is.null(n) || !nrow(n)) 0 else length(unique(n$member))))
  if (any(hit)) {
    cat(sprintf("    those attempts: %s; h / tau_s median %.2f (10-90%%: %.2f-%.2f); h median %.2f days\n",
                paste(names(table(d$outcome[hit])), table(d$outcome[hit]), sep = " ", collapse = ", "),
                median(d$h_tau[hit]), quantile(d$h_tau[hit], 0.1), quantile(d$h_tau[hit], 0.9), 365 * median(d$h[hit])))
    cat(sprintf("    by stage: %s; the member's drain over the step at its start, h (-dS/dt) / S: median %.2f (10-90%%: %.2f-%.2f); its fill at the start median %.3g\n",
                paste(names(table(n$stage)), table(n$stage), sep = ":", collapse = " "),
                median(n$drain_start), quantile(n$drain_start, 0.1), quantile(n$drain_start, 0.9), median(n$fill_start)))
    cat(sprintf("    members' births: median %.2f (10-90%%: %.2f-%.2f); attempts on dry intervals %.0f%%; deepest stage fill %.3g\n",
                median(n$birth), quantile(n$birth, 0.1), quantile(n$birth, 0.9), 100 * mean(d$wet[hit] == 0),
                min(n$fill)))
  }
}
cat("\n== (2) raises (a stage's rates throw) and non-finite error ratios\n")
for (m in names(x)) {
  d <- x[[m]]$att
  r <- !is.na(d$raised_at)
  cat(sprintf(" %s: %d raises, at stage %s; with a negative pool at the raising stage %d, with soil outside [0, theta_s] %d; non-finite ratios %d\n",
              toupper(m), sum(r), paste(names(table(d$raised_at[r])), table(d$raised_at[r]), sep = ":", collapse = " "),
              sum(d$raised_neg[r], na.rm = TRUE), sum(d$raised_soil[r], na.rm = TRUE), sum(!is.finite(d$ratio) & d$thrown == 0)))
  if (any(r)) cat(sprintf("    raising attempts: h / tau_s median %.2f (10-90%%: %.2f-%.2f); fastest pool drain at the start median %.2f; on dry intervals %.0f%%; t0 median %.1f\n",
                          median(d$h_tau[r]), quantile(d$h_tau[r], 0.1), quantile(d$h_tau[r], 0.9),
                          median(d$drain_max[r]), 100 * mean(d$wet[r] == 0), median(d$t0[r])))
}
cat("\n== (3) attempts, rejections and rows by the fastest pool's drain over the step at its start, h (-dS/dt) / S\n")
brk <- c(-Inf, 0.25, 1.038, 2.159, Inf)
lab <- c("< 0.25", "0.25-1.04", "1.04-2.16", "> 2.16")
tab3 <- NULL
for (m in names(x)) {
  d <- x[[m]]$att
  d$bin <- cut(d$drain_max, brk, labels = lab, right = FALSE)
  for (b in lab) for (w in c(1, 0)) {
    s <- d[d$bin == b & d$wet == w, ]
    tab3 <- rbind(tab3, data.frame(pair = m, drain = b, interval = if (w == 1) "wet" else "dry", attempts = nrow(s),
                                   accepted = sum(s$outcome == "accepted"), rejected = sum(s$outcome == "rejected"),
                                   thrown = sum(s$outcome == "thrown"),
                                   rej_rate = sprintf("%.1f%%", 100 * mean(s$outcome != "accepted")),
                                   rows = sum(s$members[s$outcome == "accepted"]) / 6))
  }
}
print(tab3, row.names = FALSE)
cat("  rows here = member evaluations of accepted attempts / 6 (each attempt evaluates its members six times)\n")
cat("\n by time: accepted steps and rejections per band, DP against CK\n")
for (b in list(c(0, 3), c(3, 10), c(10, 25), c(25, 40))) {
  s <- lapply(x, function(z) z$att[z$att$t0 >= b[1] & z$att$t0 < b[2], ])
  acc <- sapply(s, function(d) sum(d$outcome == "accepted")); rej <- sapply(s, function(d) sum(d$outcome != "accepted"))
  rows <- sapply(s, function(d) sum(d$members[d$outcome == "accepted"]) / 6)
  fast <- sapply(s, function(d) mean(d$drain_max[d$outcome == "accepted"] >= 1.038))
  cat(sprintf("  t %2d-%2d: accepted CK %5d DP %5d (%+.1f%%); rows %+.1f%%; rejected or thrown CK %4d DP %4d; accepted steps starting with a pool draining >= 1.04: CK %.1f%%, DP %.1f%%\n",
              b[1], b[2], acc[["ck"]], acc[["dp"]], 100 * (acc[["dp"]] / acc[["ck"]] - 1),
              100 * (rows[["dp"]] / rows[["ck"]] - 1), rej[["ck"]], rej[["dp"]], 100 * fast[["ck"]], 100 * fast[["dp"]]))
}
# By year: DP's excess steps against how often CK's steps that year start with a fast-draining pool.
yr <- 0:39
per <- sapply(x, function(z) { a <- z$att[z$att$outcome == "accepted", ]; tabulate(floor(a$t0) + 1, 40) })
fastck <- sapply(yr, function(y) { a <- x$ck$att[x$ck$att$outcome == "accepted" & floor(x$ck$att$t0) == y, ]; mean(a$drain_max >= 1.038) })
dryck <- sapply(yr, function(y) { a <- x$ck$att[x$ck$att$outcome == "accepted" & floor(x$ck$att$t0) == y, ]; mean(a$wet == 0) })
excess <- per[, "dp"] / per[, "ck"] - 1
ok <- is.finite(excess) & is.finite(fastck)
cat(sprintf("\n by year (40): DP's excess accepted steps, median %+.1f%%; correlation with the share of CK's steps starting with a pool draining >= 1.04: %.2f; with CK's dry share: %.2f\n",
            100 * median(excess[ok]), cor(excess[ok], fastck[ok]), cor(excess[ok], dryck[ok])))
