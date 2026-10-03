# Q3's report: the multirate step against bounded Cash-Karp (bnd) on long drought and
# episodic, with its coupling estimate at the soil's weight (mr, the registered candidate)
# and at the members' weight (mrw, exploratory). Cost (rows, evaluations, sub-steps), J
# against J*, the resident's frozen-structure elasticities (r = 1e-3, THETA_AFTER=1) against
# the 1e-5 reference with bnd's driver differences beside them and bnd's plant reverse mode as
# the method check, J over the tolerance ladder, the nudges, and the matched-error runs.
#   Rscript q3_report.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
M <- file.path(D, "pf_soil", "mr")
run <- function(name) { f <- file.path(M, "runs", paste0(name, ".rds")); if (file.exists(f)) readRDS(f) }
eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "resident" & eps$trait == trait & eps$unit != "curvature in lma"][1]
  if (trait == "ln J") e else max(e, 0.01)
}
J_star <- c(ld = 12.6687135, epi = 1.978902094)
record <- c(ld = "long drought", epi = "episodic")
ref_file <- c(ld = "/home/user/plant-dev/docs/measurements/nudges/ld_1e-5.rds",
              epi = file.path(D, "phase1c/full/epi_1e-5.rds"))
traits <- c("lma", "d_I", "a_dG1", "a_dG2", "omega")
E_of <- function(jp, jm, r) (log(jp) - log(jm)) / (log1p(r) - log1p(-r))
frozen <- function(prefix, r = 1e-3, tag = "") {
  vapply(traits, function(th) {
    p <- run(sprintf("%s_%s%s_p", prefix, th, tag)); m <- run(sprintf("%s_%s%s_m", prefix, th, tag))
    if (is.null(p) || is.null(m)) NA_real_ else E_of(p$J, m$J, r)
  }, 0)
}
eJ <- function(x, s) x$J / J_star[[s]] - 1
rows <- function(x) sum(x$st$M)

for (s in names(record)) {
  bnd <- readRDS(file.path(D, "pf_soil", "runs", sprintf("q1_%s.rds", s)))
  arms <- Filter(Negate(is.null), list(mr = run(sprintf("mr_%s", s)), mrw = run(sprintf("mrw_%s", s))))
  cat(sprintf("== %s\n", record[[s]]))
  # bnd's own sub-step count is zero: q1's chain sub-steps are SOIL_DIAG's estimate, not its cost.
  cost <- function(x) c(rows = rows(x), accepted = x$counts$accepted,
                        rejected = x$counts$rejected_inaccurate, evaluations = x$counts$evaluations,
                        members = x$counts$members,
                        substeps = if (is.null(x$mr)) 0 else x$counts$chain_substeps,
                        flagged = if (is.null(x$mr)) 0 else sum(x$mr))
  cb <- cost(bnd)
  cat(sprintf("   %-12s %10s %s\n", "", "bnd", paste(sprintf("%20s", names(arms)), collapse = "")))
  for (k in names(cb)) {
    cat(sprintf("   %-12s %10.0f %s\n", k, cb[[k]], paste(vapply(arms, function(x) {
      v <- cost(x)[[k]]
      sprintf("%10.0f (%+6.1f%%)", v, if (cb[[k]] > 0) 100 * (v / cb[[k]] - 1) else NA)
    }, ""), collapse = "")))
  }
  bound <- max(2 * abs(eJ(bnd, s)), 0.01 * eps_of("ln J"))
  cat(sprintf("   J/J* - 1     bnd %+.3e; %s (bound max(2 x bnd, 0.01 eps) = %.3e)\n", eJ(bnd, s),
              paste(sprintf("%s %+.3e", names(arms), vapply(arms, eJ, 0, s)), collapse = ", "), bound))

  ref <- readRDS(ref_file[[s]])$stand$elasticity[paste0("1.", traits)]
  pl <- readRDS(file.path(D, "phase1c/combined/full", sprintf("bnd_%s.rds", s)))$stand$elasticity[paste0("1.", traits)]
  e <- vapply(traits, eps_of, 0)
  Eb <- frozen(sprintf("el_%s_bnd", s))
  cat("\n   resident elasticities; distances in eps (each floored at 0.01)\n")
  cat(sprintf("   %-6s %10s %10s %10s | %8s %8s", "trait", "1e-5 ref", "bnd fz", "bnd plant", "bnd-ref", "gap"))
  for (a in names(arms)) cat(sprintf(" | %10s %8s %8s", paste(a, "fz"), paste0(a, "-ref"), paste0(a, "-bnd")))
  cat("\n")
  Ea <- lapply(names(arms), function(a) frozen(sprintf("el_%s_%s", s, a))); names(Ea) <- names(arms)
  for (i in seq_along(traits)) {
    cat(sprintf("   %-6s %10.5f %10.5f %10.5f | %+8.3f %+8.3f", traits[i], ref[i], Eb[i], pl[i],
                (Eb[i] - ref[i]) / e[i], (Eb[i] - pl[i]) / e[i]))
    for (a in names(arms)) cat(sprintf(" | %10.5f %+8.3f %+8.3f", Ea[[a]][i], (Ea[[a]][i] - ref[i]) / e[i], (Ea[[a]][i] - Eb[i]) / e[i]))
    cat("\n")
  }
  for (a in names(arms)) {
    ok <- is.finite(Ea[[a]]) & is.finite(Eb)
    if (!any(ok)) next
    dm <- abs(Ea[[a]] - ref) / e; db <- abs(Eb - ref) / e
    cat(sprintf("   %s: largest |E - ref| %.3f eps (%s); under eps/3: %s; within bnd's + 0.1 eps on every trait: %s (%d of %d traits)\n",
                a, max(dm[ok]), traits[ok][which.max(dm[ok])], all(dm[ok] < 1 / 3), all(dm[ok] <= db[ok] + 0.1),
                sum(ok), length(traits)))
  }
  if (s == "ld") {
    Em <- Ea[["mr"]]
    u4 <- frozen("el_ld_mr", 1e-4, "_u4")
    if (any(is.finite(u4))) {
      cat("   r = 1e-4 against r = 1e-3 on mr (unfrozen soil sub-steps), in eps:",
          paste(sprintf("%s %+.4f", traits[is.finite(u4)], ((u4 - Em) / e)[is.finite(u4)]), collapse = ", "), "\n")
    }
    b4 <- frozen("el_ld_bnd", 1e-4, "_u4")
    if (any(is.finite(b4))) {
      cat("   r = 1e-4 against r = 1e-3 on bnd (no sub-steps), in eps:",
          paste(sprintf("%s %+.4f", traits[is.finite(b4)], ((b4 - Eb) / e)[is.finite(b4)]), collapse = ", "), "\n")
    }
  }
  # J over the tolerance ladder, and the +-5% nudges, where run.
  for (a in c("bnd", names(arms))) {
    base <- if (a == "bnd") bnd else arms[[a]]
    lad <- c("3e-4", "1e-4", "3e-5", "1e-5")
    xs <- lapply(lad, function(t) if (t == "3e-5") base else run(sprintf("%s_%s_%s", a, s, t)))
    have <- !vapply(xs, is.null, TRUE)
    if (sum(have) >= 2) {
      cat(sprintf("   %-4s J over tol %s: J/J* - 1 %s; rows %s\n", a, paste(lad[have], collapse = ", "),
                  paste(sprintf("%+.2e", vapply(xs[have], eJ, 0, s)), collapse = ", "),
                  paste(vapply(xs[have], function(x) sprintf("%.0f", rows(x)), ""), collapse = ", ")))
    }
    nd <- lapply(c("2.85e-5", "3.15e-5"), function(t) run(sprintf("%s_%s_%s", a, s, t)))
    if (all(!vapply(nd, is.null, TRUE))) {
      cat(sprintf("   %-4s +-5%% nudges: ln J moves %s eps\n", a,
                  paste(sprintf("%+.4f", vapply(nd, function(x) log(x$J / base$J), 0) / eps_of("ln J")), collapse = ", ")))
    }
  }
  cat("\n")
}
