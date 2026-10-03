# Phase 1b's tables from the runs on disk: stage 1 (DP against CK on the driver
# in rows and error), stage 2 (per-member events on each interpolant: field
# error P1, J, cost P3) and the nudges (P2).
#   Rscript analyze1b.R [stage1|stage2|nudges|all]
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b"
DEV <- dirname(P)
R <- file.path(P, "runs")
CKR <- file.path(DEV, "events", "runs")
EPS <- read.csv("/home/user/plant-dev/.claude/worktrees/agent-a8bbf38e99929db61/docs/measurements/eps.csv")
JSTAR <- 12.6687135
what <- commandArgs(TRUE)[1]
if (is.na(what)) what <- "all"
rel <- function(J) J / JSTAR - 1

num <- function(l, pattern, k = 1) {
  m <- Filter(length, regmatches(l, regexec(pattern, l)))
  if (!length(m)) NA_real_ else as.numeric(m[[1]][k + 1])
}
read_log <- function(f) {
  if (!file.exists(f)) return(NULL)
  l <- readLines(f, warn = FALSE)
  if (!any(grepl(" J [0-9]", l))) return(NULL)
  J <- num(l, "^J to every digit ([0-9.e+-]+)")
  if (is.na(J)) J <- num(l, " J ([0-9.]+),")
  list(J = J, accepted = num(l, " J [0-9.]+, ([0-9]+) accepted"), secs = num(l, "accepted, ([0-9]+) s;"),
       replayed = num(l, "^replayed ([0-9]+) steps"), evaluations = num(l, "^rate evaluations ([0-9]+)"),
       members = num(l, "member evaluations ([0-9]+);"),
       local_members = num(l, "re-integrated on their own ([0-9]+)"),
       clamped = num(l, "; ([0-9]+) of the structure's crossings"), dips = num(l, ", ([0-9]+) dips inside one"),
       leaf = num(l, "^leaf solves ([0-9]+)"), leaf_locate = num(l, "locating ([0-9]+),"),
       leaf_sub = num(l, "sub-steps ([0-9]+),"), leaf_end = num(l, "corrected step ends ([0-9]+)"),
       leaf_dense = { x <- num(l, "dense output ([0-9]+)"); if (is.na(x)) 0 else x },
       refcheck = { x <- grep("^against the recording", l, value = TRUE); if (length(x)) x else NA })
}
lg <- function(dir, tag) read_log(file.path(dir, paste0(tag, ".log")))

stage1 <- function() {
  cat("== Stage 1: DP 5(4) against CK on the driver (long drought, seed 31, uniform 108, tied tolerance, lib_v12t)\n")
  files <- list(
    ck = c("1e-4" = file.path(CKR, "v0_1e-4.rds"), "3e-5" = file.path(DEV, "seed", "tied_3e-5.rds"),
           "1e-5" = file.path(DEV, "rej", "tied_1e-5_soil1.rds")),
    dp = c("1e-4" = file.path(R, "dp_1e-4.rds"), "3e-5" = file.path(R, "dp_3e-5.rds"),
           "1e-5" = file.path(R, "dp_1e-5.rds")))
  beta <- c(ck = 3.7343596, dp = 3.3065679)
  out <- NULL
  for (m in names(files)) for (T in names(files[[m]])) {
    f <- files[[m]][[T]]
    if (!file.exists(f)) next
    r <- readRDS(f)
    a <- r$attempts
    st <- r$st
    out <- rbind(out, data.frame(method = m, tol = T, accepted = nrow(st),
      rejected = sum(a[c("rejected_inaccurate", "rejected_thrown", "rejected_refused")]),
      thrown = a[["rejected_thrown"]], rows = sum(as.numeric(st$M)), forward = r$counts$members,
      err = rel(r$J), near = mean(st$x_soil >= 0.8), over = mean(st$x_soil > 1),
      near_ckbeta = mean(st$x_soil * beta[[m]] / beta[["ck"]] >= 0.8)))
  }
  if (is.null(out)) return(invisible())
  print(transform(out, err = sprintf("%+.2e", err), near = sprintf("%.2f%%", 100 * near),
                  over = sprintf("%.2f%%", 100 * over), near_ckbeta = sprintf("%.2f%%", 100 * near_ckbeta),
                  rej_share = sprintf("%.1f%%", 100 * rejected / (accepted + rejected))), row.names = FALSE)
  cat("  near/over: steps starting at h|lambda_soil|/beta >= 0.8 / > 1 with the pair's own beta; near_ckbeta: DP's h|lambda| against CK's beta\n")
  cat("\n DP against CK at equal tol (gradient = (forward + 6 rows) / 7, harness/rows.R):\n")
  for (T in unique(out$tol)) {
    ck <- out[out$method == "ck" & out$tol == T, ]; dp <- out[out$method == "dp" & out$tol == T, ]
    if (!nrow(ck) || !nrow(dp)) next
    cat(sprintf("  %s: accepted %+.1f%%, rows %+.1f%%, forward %+.1f%%, gradient run %+.1f%%, rejected %d vs %d; |J - J*| %.2e vs %.2e\n",
                T, 100 * (dp$accepted / ck$accepted - 1), 100 * (dp$rows / ck$rows - 1),
                100 * (dp$forward / ck$forward - 1),
                100 * ((dp$forward / ck$forward + 6 * dp$rows / ck$rows) / 7 - 1), dp$rejected, ck$rejected,
                abs(dp$err), abs(ck$err)))
  }
  # Rows at matched |J - J*|: log rows against log |err|, piecewise linear in
  # each method's own three points, read where both are resolved (> 3e-6).
  cat("\n rows at matched |J - J*| (piecewise log-log in each method's three points):\n")
  fit <- function(m) { x <- out[out$method == m, ]; x[order(abs(x$err)), ] }
  ck <- fit("ck"); dp <- fit("dp")
  mono <- function(x) all(diff(log(abs(x$err))) * diff(log(x$rows)) <= 0)
  cat(sprintf("  error falls monotonically as rows rise: CK %s, DP %s\n", mono(ck), mono(dp)))
  for (i in seq_len(nrow(ck))) {
    e <- abs(ck$err[i])
    if (e < 3e-6 || e < min(abs(dp$err)) || e > max(abs(dp$err))) {
      cat(sprintf("  CK at %s (|err| %.2e): outside DP's resolved range\n", ck$tol[i], e)); next
    }
    rr <- exp(approx(log(abs(dp$err)), log(dp$rows), log(e))$y)
    cat(sprintf("  CK at %s (|err| %.2e, rows %.0f): DP's rows at that error %.0f (%+.1f%%)\n",
                ck$tol[i], e, ck$rows[i], rr, 100 * (rr / ck$rows[i] - 1)))
  }
  chk <- lg(R, "ck_1e-4_check")
  if (!is.null(chk)) cat(sprintf("\n CK through the patched driver at 1e-4: J %.9f; %s\n", chk$J, chk$refcheck))
  for (T in c("1e-4", "3e-5")) {
    g <- lg(R, paste0("g_dp_", T))
    if (!is.null(g)) cat(sprintf(" DP through the events driver on the probe build at %s: %s\n", T, g$refcheck))
  }
  invisible(out)
}

field_table <- function(f) {
  if (!file.exists(f)) return(NULL)
  d <- readRDS(f)
  do.call(rbind, lapply(split(d, d$kind), function(x) {
    ps <- tapply(x$field, x$row, max); so <- tapply(x$soil, x$row, max); me <- tapply(x$members, x$row, max)
    data.frame(kind = x$kind[1], steps = length(ps), over1 = sum(ps > 1), soil_over1 = sum(so > 1),
               members_over1 = sum(me > 1), median = median(ps), q90 = quantile(ps, 0.9),
               q99 = quantile(ps, 0.99), max = max(ps),
               ratio_med = median(x$field / pmax(x$step_ratio, 1e-12)))
  }))
}

stage2 <- function() {
  cat("\n== Stage 2: per-member events on each interpolant (probe build; long drought, uniform 108, tied)\n")
  cat(" P1, the split's field against a same-pair step of u h, in error weights, per crossing step (max over u = 1/4, 1/2, 3/4):\n")
  for (T in c("1e-4", "3e-5")) for (m in c("ck", "dp")) {
    ft <- field_table(file.path(R, sprintf("dc_%s_%s.rds", m, T)))
    if (is.null(ft)) next
    cat(sprintf("  %s grid at %s:\n", toupper(m), T))
    print(format(ft, digits = 3), row.names = FALSE)
  }
  cat("\n J, and the split's cost in leaf solves (added = split - plain; of the plain replay and of the plain adaptive forward):\n")
  arms <- list(
    list(T = "1e-4", pair = "CK", arm = "plain", dir = CKR, tag = "rp_1e-4"),
    list(T = "1e-4", pair = "CK", arm = "cubic", dir = CKR, tag = "sp_1e-4", fwd = "ga_1e-4"),
    list(T = "1e-4", pair = "CK", arm = "quintic", dir = CKR, tag = "spq_1e-4", fwd = "gaq_1e-4"),
    list(T = "1e-4", pair = "CK", arm = "ck4", dir = R, tag = "sp_ck4_1e-4", fwd = "ga_ck4_1e-4"),
    list(T = "1e-4", pair = "DP", arm = "plain", dir = R, tag = "rp_dp_1e-4"),
    list(T = "1e-4", pair = "DP", arm = "cubic", dir = R, tag = "sp_dpc_1e-4"),
    list(T = "1e-4", pair = "DP", arm = "quintic", dir = R, tag = "sp_dpq_1e-4"),
    list(T = "1e-4", pair = "DP", arm = "dp4", dir = R, tag = "sp_dp4_1e-4", fwd = "ga_dp4_1e-4"),
    list(T = "3e-5", pair = "CK", arm = "plain", dir = CKR, tag = "rp_3e-5"),
    list(T = "3e-5", pair = "CK", arm = "cubic", dir = CKR, tag = "sp_3e-5", fwd = "ga_3e-5"),
    list(T = "3e-5", pair = "CK", arm = "quintic", dir = CKR, tag = "spq_3e-5"),
    list(T = "3e-5", pair = "CK", arm = "ck4", dir = R, tag = "sp_ck4_3e-5"),
    list(T = "3e-5", pair = "DP", arm = "plain", dir = R, tag = "rp_dp_3e-5"),
    list(T = "3e-5", pair = "DP", arm = "dp4", dir = R, tag = "sp_dp4_3e-5", fwd = "ga_dp4_3e-5"))
  rows <- NULL
  for (a in arms) {
    s <- lg(a$dir, a$tag)
    if (is.null(s)) next
    base_dir <- if (a$pair == "CK") CKR else R
    rp <- lg(base_dir, if (a$pair == "CK") paste0("rp_", a$T) else paste0("rp_dp_", a$T))
    g <- lg(base_dir, if (a$pair == "CK") paste0("g_", a$T) else paste0("g_dp_", a$T))
    ga <- if (!is.null(a$fwd)) lg(a$dir, a$fwd) else NULL
    add <- if (a$arm == "plain" || is.null(rp)) NA else s$leaf - rp$leaf
    rows <- rbind(rows, data.frame(tol = a$T, pair = a$pair, arm = a$arm, err = sprintf("%+.2e", rel(s$J)),
      split = s$local_members, add_replay = if (is.na(add)) "" else sprintf("%+.2f%%", 100 * add / rp$leaf),
      add_over_fwd = if (is.na(add) || is.null(g)) "" else sprintf("%+.2f%%", 100 * add / g$leaf),
      fwd_with_split = if (is.null(ga) || is.null(g)) "" else sprintf("%+.2f%%", 100 * (ga$leaf / g$leaf - 1)),
      locate = if (a$arm == "plain") "" else sprintf("%.2f%%", 100 * s$leaf_locate / g$leaf),
      substeps = if (a$arm == "plain") "" else sprintf("%.2f%%", 100 * s$leaf_sub / g$leaf),
      ends = if (a$arm == "plain") "" else sprintf("%.2f%%", 100 * s$leaf_end / g$leaf),
      dense = if (a$arm == "plain") "" else sprintf("%.2f%%", 100 * s$leaf_dense / g$leaf),
      fwd_err = if (is.null(ga)) "" else sprintf("%+.2e", rel(ga$J))))
  }
  if (!is.null(rows)) print(rows, row.names = FALSE)
  cat("  locate/substeps/ends/dense: the split's leaf solves in the replay, each over the plain adaptive forward's\n")
  for (T in c("1e-4", "3e-5")) {
    g <- lg(R, paste0("g_dp_", T)); gc <- lg(CKR, paste0("g_", T))
    if (!is.null(g) && !is.null(gc)) cat(sprintf("  plain adaptive forwards at %s: CK %d accepted, %.4g leaf solves; DP %d accepted, %.4g leaf solves (%+.1f%%)\n",
                                                T, gc$accepted, gc$leaf, g$accepted, g$leaf, 100 * (g$leaf / gc$leaf - 1)))
  }
}

diffs <- function(Jp, Jm, J0, r) {
  hp <- log1p(r); hm <- -log1p(-r)
  fp <- log(Jp); fm <- log(Jm); f0 <- log(J0)
  c(e = (fp - fm) / (hp + hm), H = 2 * (fp / (hp * (hp + hm)) + fm / (hm * (hp + hm)) - f0 / (hp * hm)))
}
TOLS <- c("9.5e-5", "9.7e-5", "9.85e-5", "1e-4", "1.015e-4", "1.03e-4", "1.05e-4")
nudges <- function(arm = "dp4", traits = c("d_I", "a_dG1", "a_dG2", "lma")) {
  cat(sprintf("\n== P2: the seven nudges within 5%% of 1e-4 on the %s split, central differences at r = 1e-3 on each run's frozen structure\n", arm))
  quintic <- c(a_dG1 = 0.06, d_I = 0.11, a_dG2 = 0.05, lma = 0.02)          # SD in eps/3, final_nudges.txt
  quintic_max <- c(lnJ = 0.001, a_dG1 = 0.174, d_I = 0.282, a_dG2 = 0.138, lma = 0.059)
  plain_max <- c(lnJ = 0.003, a_dG1 = 1.048, d_I = 1.261, a_dG2 = 0.906, lma = 0.477)
  tab <- data.frame(tol = TOLS)
  base <- lapply(TOLS, function(T) lg(R, sprintf("sp_%s_%s", arm, T)))
  tab$steps <- sapply(TOLS, function(T) { g <- lg(R, paste0("g_dp_", T)); if (is.null(g)) NA else g$accepted })
  tab$lnJ <- sapply(base, function(b) if (is.null(b)) NA else log(b$J))
  for (tr in traits) {
    tab[[tr]] <- sapply(seq_along(TOLS), function(k) {
      p <- lg(R, sprintf("fq_%s_%s_%s_1e-3", arm, TOLS[k], tr)); m <- lg(R, sprintf("fq_%s_%s_%s_-1e-3", arm, TOLS[k], tr))
      if (is.null(p) || is.null(m) || is.null(base[[k]])) NA else diffs(p$J, m$J, base[[k]]$J, 1e-3)[["e"]]
    })
  }
  print(format(tab, digits = 8), row.names = FALSE)
  i0 <- which(TOLS == "1e-4")
  cat(" quantity  max move (eps/3)  sd (eps/3)   n   quintic max/sd   plain max   P2\n")
  for (q in c("lnJ", traits)) {
    x <- tab[[q]]
    if (all(is.na(x)) || is.na(x[i0])) { cat(sprintf(" %-7s   not measured\n", q)); next }
    e3 <- EPS$eps[EPS$role == "resident" & EPS$trait == if (q == "lnJ") "ln J" else q] / 3
    mv <- max(abs(x[-i0] - x[i0]), na.rm = TRUE) / e3
    sdv <- sd(x, na.rm = TRUE) / e3
    nn <- sum(!is.na(x))
    pass <- if (q == "lnJ" || nn < 7) "" else if (sdv <= 1.5 * quintic[[q]] && mv < 1) "pass" else "fail"
    cat(sprintf(" %-7s   %8.3f          %7.3f     %d   %6.3f/%s       %6.3f      %s\n", q, mv, sdv, nn,
                quintic_max[[q]], if (q == "lnJ") "  -  " else sprintf("%.2f", quintic[[q]]), plain_max[[q]], pass))
  }
  invisible(tab)
}

# P2 on the CK grids, paired: the plain arm by reverse mode (the spike's ad_T),
# the quintic split's and CK's quartic split's by central differences at
# r = 1e-3 on each run's frozen structure.
nudges_ck <- function(traits = c("d_I", "a_dG1", "a_dG2", "lma")) {
  cat("\n== P2 on the spike's seven CK grids: plain (reverse mode), quintic split and CK quartic split (frozen-structure differences, r = 1e-3)\n")
  quintic_sd <- c(a_dG1 = 0.06, d_I = 0.11, a_dG2 = 0.05, lma = 0.02)   # pre-registered, final_nudges.txt
  fq_q <- function(T, tr, r) lg(CKR, if (tr == "lma" && T == "1e-4") sprintf("fq_lma_%s", r) else sprintf("fq_%s_%s_%s", T, tr, r))
  arms <- list(
    plain = function(T, tr) {
      f <- file.path(CKR, sprintf("ad_%s.rds", T))
      if (file.exists(f)) readRDS(f)$elasticity[[paste0("1.", tr)]] else NA
    },
    quintic = function(T, tr) {
      p <- fq_q(T, tr, "1e-3"); m <- fq_q(T, tr, "-1e-3"); b <- lg(CKR, paste0("spq_", T))
      if (is.null(p) || is.null(m) || is.null(b)) NA else diffs(p$J, m$J, b$J, 1e-3)[["e"]]
    },
    ck4 = function(T, tr) {
      p <- lg(R, sprintf("fq_ck4_%s_%s_1e-3", T, tr)); m <- lg(R, sprintf("fq_ck4_%s_%s_-1e-3", T, tr))
      b <- lg(R, paste0("sp_ck4_", T))
      if (is.null(p) || is.null(m) || is.null(b)) NA else diffs(p$J, m$J, b$J, 1e-3)[["e"]]
    })
  lnJ <- list(plain = function(T) { g <- lg(CKR, paste0("g_", T)); if (is.null(g)) NA else log(g$J) },
              quintic = function(T) { g <- lg(CKR, paste0("spq_", T)); if (is.null(g)) NA else log(g$J) },
              ck4 = function(T) { g <- lg(R, paste0("sp_ck4_", T)); if (is.null(g)) NA else log(g$J) })
  i0 <- which(TOLS == "1e-4")
  res <- NULL
  for (q in c("lnJ", traits)) {
    e3 <- EPS$eps[EPS$role == "resident" & EPS$trait == if (q == "lnJ") "ln J" else q] / 3
    vals <- sapply(names(arms), function(a) sapply(TOLS, function(T) if (q == "lnJ") lnJ[[a]](T) else arms[[a]](T, q)))
    if (q != "lnJ") {
      cat(sprintf(" %s by tolerance:\n", q))
      print(format(data.frame(tol = TOLS, vals), digits = 8), row.names = FALSE)
    }
    for (a in colnames(vals)) {
      x <- vals[, a]
      if (is.na(x[i0])) next
      res <- rbind(res, data.frame(quantity = q, arm = a, n = sum(!is.na(x)),
                                   max_move = max(abs(x[-i0] - x[i0]), na.rm = TRUE) / e3,
                                   sd = sd(x, na.rm = TRUE) / e3, mean = mean(x, na.rm = TRUE)))
    }
  }
  res$P2 <- ""
  for (k in which(res$arm == "ck4" & res$quantity != "lnJ")) {
    q <- res$quantity[k]
    res$P2[k] <- if (res$n[k] < 7) "incomplete" else
      if (res$sd[k] <= 1.5 * quintic_sd[[q]] && res$max_move[k] < 1) "pass" else "fail"
  }
  cat(" spread in eps/3 (max move from the 1e-4 run over the other six; sd over all seven); mean in its own units:\n")
  print(format(res, digits = 4), row.names = FALSE)
  # One-sided slopes at r = 1e-3 on the quartic's frozen structures: their gap
  # is r H plus any jump inside +-r, so a gap far from the 1e-4 grid's flags one.
  gap <- function(T, tr) {
    p <- lg(R, sprintf("fq_ck4_%s_%s_1e-3", T, tr)); m <- lg(R, sprintf("fq_ck4_%s_%s_-1e-3", T, tr))
    b <- lg(R, paste0("sp_ck4_", T))
    if (is.null(p) || is.null(m) || is.null(b)) return(NA)
    (log(p$J) - log(b$J)) / log1p(1e-3) - (log(b$J) - log(m$J)) / -log1p(-1e-3)
  }
  cat(" the quartic's one-sided gaps less the 1e-4 grid's, in eps/3 (a jump shows as a large value):\n")
  for (q in traits) {
    e3 <- EPS$eps[EPS$role == "resident" & EPS$trait == q] / 3
    g0 <- gap("1e-4", q)
    if (is.na(g0)) next
    v <- sapply(TOLS[TOLS != "1e-4"], function(T) (gap(T, q) - g0) / e3)
    cat(sprintf("  %-6s 1e-4 gap %.3g (%.2f eps/3); others %s\n", q, g0, g0 / e3, paste(sprintf("%.2f", v), collapse = " ")))
  }
  for (q in traits) {
    e3 <- EPS$eps[EPS$role == "resident" & EPS$trait == q] / 3
    m <- res[res$quantity == q, ]
    if (all(c("quintic", "ck4") %in% m$arm)) {
      cat(sprintf(" %-6s mean of ck4 - mean of quintic: %+.3f eps/3; of quintic - plain: %+.3f eps/3\n", q,
                  (m$mean[m$arm == "ck4"] - m$mean[m$arm == "quintic"]) / e3,
                  (m$mean[m$arm == "quintic"] - m$mean[m$arm == "plain"]) / e3))
    }
  }
  invisible(res)
}

if (what %in% c("stage1", "all")) stage1()
if (what %in% c("stage2", "all")) stage2()
if (what %in% c("nudges_dp")) nudges()
if (what %in% c("nudges", "all")) nudges_ck()
