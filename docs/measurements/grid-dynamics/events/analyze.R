# The events spike's tables, from the logs in runs/: the split's cost in leaf
# solves (stage 1), lma's chord on the 1e-4 grid (stage 2) and the spread under
# the record's seven tolerance nudges (stage 3), against eps.csv.
#   Rscript analyze.R [cost|chord|nudges|all]
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
R <- file.path(E, "runs")
EPS <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
# Cash-Karp at 1e-8 under the tied tolerance (docs/grid-dynamics.md section 1).
JSTAR <- 12.6687135
what <- commandArgs(TRUE)[1]
if (is.na(what)) what <- "all"

num <- function(l, pattern, k = 1) {
  m <- regmatches(l, regexec(pattern, l))
  m <- Filter(length, m)
  if (!length(m)) NA_real_ else as.numeric(m[[1]][k + 1])
}
read_log <- function(tag) {
  f <- file.path(R, paste0(tag, ".log"))
  if (!file.exists(f)) return(NULL)
  l <- readLines(f, warn = FALSE)
  if (!any(grepl(" J [0-9]", l))) return(NULL)
  J <- num(l, "^J to every digit ([0-9.e+-]+)")
  if (is.na(J)) {
    rds <- file.path(R, paste0(tag, ".rds"))
    J <- if (file.exists(rds)) readRDS(rds)$J else num(l, " J ([0-9.]+),")
  }
  list(J = J,
       accepted = num(l, " J [0-9.]+, ([0-9]+) accepted"),
       secs = num(l, "accepted, ([0-9]+) s;"),
       replayed = num(l, "^replayed ([0-9]+) steps"),
       evaluations = num(l, "^rate evaluations ([0-9]+)"),
       members = num(l, "member evaluations ([0-9]+);"),
       local_members = num(l, "re-integrated on their own ([0-9]+)"),
       local_evaluations = num(l, "re-integrated on their own [0-9]+, in ([0-9]+) member"),
       clamped = num(l, "; ([0-9]+) of the structure's crossings"),
       split_secs = num(l, "; ([0-9.]+) s in the split"),
       leaf = num(l, "^leaf solves ([0-9]+)"),
       leaf_locate = num(l, "locating ([0-9]+),"),
       leaf_sub = num(l, "sub-steps ([0-9]+),"),
       leaf_end = num(l, "corrected step ends ([0-9]+)"),
       refcheck = { x <- grep("^against the recording", l, value = TRUE); if (length(x)) x else NA })
}
eps_of <- function(role, trait) {
  key <- if (trait == "lnJ") "ln J" else trait
  EPS$eps[EPS$role == role & EPS$trait == key]
}
pct <- function(x) sprintf("%+.2f%%", 100 * x)

cost <- function() {
  cat("== Stage 1: the split's cost in leaf solves (long drought, seed 31, uniform 108, tied tolerance)\n")
  v0 <- read_log("v0_1e-4"); g <- read_log("g_1e-4")
  if (!is.null(v0) && !is.null(g)) {
    cat(sprintf("probe present and unused: lib_v12t J %.17g, probe build J %.17g; %s\n",
                v0$J, g$J, g$refcheck))
  }
  for (tol in c("1e-4", "3e-5")) {
    g <- read_log(paste0("g_", tol)); rp <- read_log(paste0("rp_", tol))
    sp <- read_log(paste0("sp_", tol)); ga <- read_log(paste0("ga_", tol))
    spw <- read_log(paste0("spw_", tol))
    if (is.null(g)) next
    cat(sprintf("\n tol %s: adaptive forward %d accepted, %d evaluations, %.4g member evaluations, %.4g leaf solves, %d s\n",
                tol, g$accepted, g$evaluations, g$members, g$leaf, g$secs))
    if (!is.null(rp)) {
      cat(sprintf("  plain replay: %d steps, %d evaluations, %.4g member evaluations, %.4g leaf solves (members + 2 per evaluation: %.4g), %d s; J %s the forward's\n",
                  rp$replayed, rp$evaluations, rp$members, rp$leaf, rp$members + 2 * rp$evaluations, rp$secs,
                  if (identical(rp$J, g$J)) "equals" else sprintf("differs by %.3g from", rp$J - g$J)))
    }
    if (!is.null(sp) && !is.null(rp)) {
      add <- sp$leaf - rp$leaf
      cat(sprintf("  split replay (single-member): %d members re-integrated, %d single-member evaluations, %.4g leaf solves, %d s (%.0f s in the split)\n",
                  sp$local_members, sp$local_evaluations, sp$leaf, sp$secs, sp$split_secs))
      cat(sprintf("    added leaf solves %.4g = locating %.4g + sub-steps %.4g + corrected step ends %.4g; %s of the plain replay, %s of the adaptive forward; wall %s\n",
                  add, sp$leaf_locate, sp$leaf_sub, sp$leaf_end, pct(add / rp$leaf), pct(add / g$leaf),
                  pct(sp$secs / rp$secs - 1)))
      cat(sprintf("    per member split: %.1f leaf solves locating, %.1f in the sub-steps; J with the split %.12g (%+.3g relative to plain)\n",
                  sp$leaf_locate / sp$local_members, sp$leaf_sub / sp$local_members, sp$J, sp$J / rp$J - 1))
      cat(sprintf("    against J* = %.7f (Cash-Karp at 1e-8, tied): plain %+.3g, split %+.3g relative\n",
                  JSTAR, rp$J / JSTAR - 1, sp$J / JSTAR - 1))
    }
    if (!is.null(spw) && !is.null(sp)) {
      cat(sprintf("  split replay (whole-patch evaluation, the first cut): J %s the single-member split's; %.4g leaf solves (%s of plain), %d s (%s)\n",
                  if (identical(spw$J, sp$J)) "identical to" else sprintf("differs by %.3g from", spw$J - sp$J),
                  spw$leaf, pct(spw$leaf / rp$leaf - 1), spw$secs, pct(spw$secs / rp$secs - 1)))
    }
    if (!is.null(ga)) {
      cat(sprintf("  adaptive forward with the split: %d accepted, %.4g leaf solves (%s of the plain forward), %d s; split's own %.4g; J %.12g\n",
                  ga$accepted, ga$leaf, pct(ga$leaf / g$leaf - 1), ga$secs,
                  ga$leaf_locate + ga$leaf_sub + ga$leaf_end, ga$J))
    }
  }
}

# Elasticity and second difference of ln J in ln theta from J at theta (1 + r),
# theta (1 - r) and theta.
diffs <- function(Jp, Jm, J0, r) {
  hp <- log1p(r); hm <- -log1p(-r)
  fp <- log(Jp); fm <- log(Jm); f0 <- log(J0)
  c(e = (fp - fm) / (hp + hm),
    H = 2 * (fp / (hp * (hp + hm)) + fm / (hm * (hp + hm)) - f0 / (hp * hm)))
}

chord <- function() {
  cat("\n== Stage 2: lma alone on the 1e-4 grid; elasticity e(r) and second difference H(r) of ln J\n")
  base <- list(rp = read_log("rp_1e-4"), sp = read_log("sp_1e-4"), fp = read_log("fp_0"), fq = read_log("spq_1e-4"))
  if (!is.null(base$fp) && !is.null(base$sp)) {
    cat(sprintf("frozen structure at lma itself: J %s the split's\n",
                if (identical(base$fp$J, base$sp$J)) "identical to" else sprintf("differs by %.3g from", base$fp$J - base$sp$J)))
  }
  arms <- c(rp = "plain", sp = "split, re-detected", fp = "split, frozen structure",
            fq = "split, frozen, quintic field")
  out <- NULL
  for (a in names(arms)) for (r in c(1e-6, 1e-5, 1e-4, 3e-4, 1e-3, 1e-2)) {
    rs <- format(r, scientific = TRUE); rs <- sub("e-0", "e-", rs)
    p <- read_log(sprintf("%s_lma_%s", a, rs)); m <- read_log(sprintf("%s_lma_-%s", a, rs))
    b <- if (a == "fp") base$sp else if (a == "fq") base$fq else base[[a]]
    if (is.null(p) || is.null(m) || is.null(b)) next
    d <- diffs(p$J, m$J, b$J, r)
    out <- rbind(out, data.frame(arm = arms[[a]], r = r, e = d[["e"]], H = d[["H"]],
                                 dJp = p$J - b$J, dJm = m$J - b$J,
                                 clamped = paste(p$clamped, m$clamped, sep = "/")))
  }
  if (!is.null(out)) print(format(out, digits = 7), row.names = FALSE)
  invisible(out)
}

TOLS <- c("9.5e-5", "9.7e-5", "9.85e-5", "1e-4", "1.015e-4", "1.03e-4", "1.05e-4")
TRAITS <- c("a_dG1", "d_I", "a_dG2", "lma")
# A trait's elasticity by central differences at r = 1e-5 on arm `a` ("rp"
# plain, "fq" the quintic split's frozen structure) at tolerance T, about base J.
fd_elasticity <- function(a, T, trait, b, r = "1e-6") {
  tag <- function(r) if (trait == "lma" && T == "1e-4") sprintf("%s_lma_%s", a, r) else sprintf("%s_%s_%s_%s", a, T, trait, r)
  p <- read_log(tag(r)); m <- read_log(tag(paste0("-", r)))
  if (is.null(p) || is.null(m) || is.null(b)) NA else diffs(p$J, m$J, b$J, as.numeric(r))[["e"]]
}
read_ad <- function(T) { f <- file.path(R, sprintf("ad_%s.rds", T)); if (file.exists(f)) readRDS(f) else NULL }
nudges <- function() {
  cat("\n== Stage 3: the record's seven nudges within 5% of 1e-4; largest move from the 1e-4 run, in eps/3\n")
  ad0 <- read_ad("1e-4"); g0 <- read_log("g_1e-4")
  if (!is.null(ad0)) {
    cat("instruments at 1e-4: reverse mode on lib_v12t against the driver's central differences, plain (rp) and on the quintic split's frozen structure (fq), at r = 1e-6 and 1e-5\n")
    for (trait in TRAITS) {
      a <- ad0$elasticity[[paste0("1.", trait)]]; e3 <- eps_of("resident", trait) / 3
      x <- c(rp6 = fd_elasticity("rp", "1e-4", trait, read_log("rp_1e-4"), "1e-6"),
             rp5 = fd_elasticity("rp", "1e-4", trait, read_log("rp_1e-4"), "1e-5"),
             rp3 = fd_elasticity("rp", "1e-4", trait, read_log("rp_1e-4"), "1e-3"),
             fq4 = fd_elasticity("fq", "1e-4", trait, read_log("spq_1e-4"), "1e-4"),
             fq3 = fd_elasticity("fq", "1e-4", trait, read_log("spq_1e-4"), "1e-3"))
      x <- x[!is.na(x)]
      cat(sprintf("  %-6s AD %.8g | %s\n", trait, a,
                  paste(sprintf("%s %.8g (%+.3f eps/3)", names(x), x, (x - a) / e3), collapse = "; ")))
    }
  }
  rows <- NULL
  for (T in TOLS) {
    g <- read_log(paste0("g_", T)); sq <- read_log(paste0("spq_", T)); ad <- read_ad(T)
    row <- data.frame(tol = T, steps = if (is.null(g)) NA else g$accepted,
                      grid_same = if (is.null(g) || is.null(ad)) NA else identical(g$J, ad$J),
                      lnJ_plain = if (is.null(g)) NA else log(g$J),
                      lnJ_split = if (is.null(sq)) NA else log(sq$J))
    for (trait in TRAITS) {
      row[[paste0(trait, ".plain")]] <- if (is.null(ad)) NA else ad$elasticity[[paste0("1.", trait)]]
      row[[paste0(trait, ".split")]] <- fd_elasticity("fq", T, trait, sq, "1e-3")
    }
    row[["a_dG1.plain_fd"]] <- fd_elasticity("rp", T, "a_dG1", g, "1e-3")
    rows <- rbind(rows, row)
  }
  print(format(rows, digits = 8), row.names = FALSE)
  # One-sided slopes of each split point at r = 1e-3: their gap is r H plus any
  # jump inside +-r, so a gap far from the same trait's on the base grid flags
  # a jump (a dip vanishing, say).
  gap <- function(T, trait) {
    tag <- function(r) if (trait == "lma" && T == "1e-4") sprintf("fq_lma_%s", r) else sprintf("fq_%s_%s_%s", T, trait, r)
    p <- read_log(tag("1e-3")); m <- read_log(tag("-1e-3")); b <- read_log(paste0("spq_", T))
    if (is.null(p) || is.null(m) || is.null(b)) return(NA)
    (log(p$J) - log(b$J)) / log1p(1e-3) - (log(b$J) - log(m$J)) / -log1p(-1e-3)
  }
  cat("\n split points' one-sided gap less the base grid's, in eps/3 (a jump shows as a large value):\n")
  for (trait in TRAITS) {
    g0 <- gap("1e-4", trait); e3 <- eps_of("resident", trait) / 3
    v <- sapply(TOLS, function(T) (gap(T, trait) - g0) / e3)
    cat(sprintf("  %-6s base gap %.4g (%.2f eps/3); others %s\n", trait, g0, g0 / e3,
                paste(sprintf("%.2f", v[TOLS != "1e-4"]), collapse = " ")))
  }
  base <- rows[rows$tol == "1e-4", ]
  cat("\n quantity            plain: move/(eps/3)   split: move/(eps/3)   (abs moves)\n")
  q <- list(lnJ = c("lnJ_plain", "lnJ_split"))
  for (trait in TRAITS) q[[trait]] <- paste0(trait, c(".plain", ".split"))
  q[["a_dG1 (plain by differences at 1e-3 against split)"]] <- c("a_dG1.plain_fd", "a_dG1.split")
  res <- NULL
  for (k in names(q)) {
    e3 <- eps_of("resident", sub(" .*", "", k)) / 3
    mv <- sapply(q[[k]], function(col) {
      x <- rows[[col]] - base[[col]]; x <- x[rows$tol != "1e-4"]
      if (all(is.na(x))) NA else max(abs(x), na.rm = TRUE)
    })
    n_ok <- sapply(q[[k]], function(col) sum(!is.na(rows[[col]])))
    cat(sprintf(" %-8s  %8.3f (%d of 7)        %8.3f (%d of 7)        (%.3g, %.3g)\n",
                k, mv[1] / e3, n_ok[1], mv[2] / e3, n_ok[2], mv[1], mv[2]))
    res <- rbind(res, data.frame(quantity = k, plain = mv[1] / e3, split = mv[2] / e3))
  }
  # The plain arm over every quantity reverse mode gives, as the record states it.
  ads <- lapply(TOLS, read_ad)
  if (!any(vapply(ads, is.null, TRUE))) {
    E0 <- ads[[which(TOLS == "1e-4")]]$elasticity
    worst <- sapply(names(E0), function(nm) {
      e3 <- eps_of("resident", sub("^1\\.", "", nm)) / 3
      if (!length(e3) || is.na(e3)) return(NA)
      max(abs(sapply(ads[TOLS != "1e-4"], function(a) a$elasticity[[nm]]) - E0[[nm]])) / e3
    })
    worst <- sort(worst[!is.na(worst)], decreasing = TRUE)
    cat(sprintf("\n plain arm, every elasticity by reverse mode: %d of %d above eps/3, median %.2f; the largest:\n",
                sum(worst > 1), length(worst), median(worst)))
    print(round(head(worst, 8), 3))
  }
  invisible(list(rows = rows, spread = res))
}

# The split's move of J as the crossing steps (the rows the base split log
# names) are cut into 2 and 4: an error of the interpolant the split reads goes
# as h^4, one of the kink's straddle as h^2.
halving <- function() {
  cat("\n== The split's move of J with the crossing steps cut into n (1e-4 grid)\n")
  for (n in c(1, 2, 4)) {
    rp <- read_log(if (n == 1) "rp_1e-4" else sprintf("rp_h%d", n))
    sp <- read_log(if (n == 1) "sp_1e-4" else sprintf("sp_h%d", n))
    if (is.null(rp) || is.null(sp)) next
    cat(sprintf(" n %d: plain J %.12g (%+.3g vs J*), split %.12g (%+.3g vs J*); split - plain %+.4g relative; split's leaf solves %.4g\n",
                n, rp$J, rp$J / JSTAR - 1, sp$J, sp$J / JSTAR - 1, sp$J / rp$J - 1, sp$leaf - rp$leaf))
  }
}

dense <- function() {
  cat("\n== The split's field from the cubic through the step's ends against the quintic through its midpoint\n")
  for (tol in c("1e-4", "3e-5")) {
    rp <- read_log(paste0("rp_", tol)); sp <- read_log(paste0("sp_", tol)); sq <- read_log(paste0("spq_", tol))
    if (is.null(rp) || is.null(sp) || is.null(sq)) next
    f <- file.path(R, paste0("spq_", tol, ".log")); l <- readLines(f, warn = FALSE)
    ld <- num(l, "dense output ([0-9]+)")
    cat(sprintf(" tol %s: plain %+.3g vs J*; split, cubic %+.3g (move %+.3g); split, quintic %+.3g (move %+.3g); quintic's leaf solves %+.2f%% of plain (its midpoints %.4g)\n",
                tol, rp$J / JSTAR - 1, sp$J / JSTAR - 1, sp$J / rp$J - 1, sq$J / JSTAR - 1, sq$J / rp$J - 1,
                100 * (sq$leaf - rp$leaf) / rp$leaf, ld))
  }
  g <- read_log("g_1e-4"); gq <- read_log("gaq_1e-4")
  if (!is.null(g) && !is.null(gq)) {
    cat(sprintf(" adaptive forward at 1e-4 with the quintic split: %d accepted (plain %d), %.4g leaf solves, %+.2f%% of the plain forward; J %+.3g vs J*\n",
                gq$accepted, g$accepted, gq$leaf, 100 * (gq$leaf / g$leaf - 1), gq$J / JSTAR - 1))
  }
}

if (what %in% c("cost", "all")) cost()
if (what %in% c("dense", "all")) dense()
if (what %in% c("halving", "all")) halving()
if (what %in% c("chord", "all")) chord()
if (what %in% c("nudges", "all")) nudges()
