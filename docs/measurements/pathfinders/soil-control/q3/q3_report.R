# Q3's report: the multirate step (mr) against bounded Cash-Karp (bnd) on long drought
# and episodic. Cost (rows, evaluations, sub-steps), J against J*, and the resident's
# frozen-structure elasticities (r = 1e-3, THETA_AFTER=1) for mr's and bnd's driver
# programs against the 1e-5 reference, with bnd's plant reverse mode as the method check.
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

for (s in names(record)) {
  mr <- run(sprintf("mr_%s", s)); bnd <- readRDS(file.path(D, "pf_soil", "runs", sprintf("q1_%s.rds", s)))
  cat(sprintf("== %s\n", record[[s]]))
  cost <- function(x) c(rows = sum(x$st$M), accepted = x$counts$accepted,
                        rejected = x$counts$rejected_inaccurate, evaluations = x$counts$evaluations,
                        members = x$counts$members,
                        substeps = if (is.null(x$mr)) 0 else x$counts$chain_substeps,
                        flagged = if (is.null(x$mr)) 0 else sum(x$mr))
  # bnd's own sub-step count is zero: q1's chain sub-steps are SOIL_DIAG's estimate, not its cost.
  cm <- cost(mr); cb <- cost(bnd)
  for (k in names(cm)) cat(sprintf("   %-12s mr %9.0f  bnd %9.0f  (%+.1f%%)\n", k, cm[[k]], cb[[k]],
                                   if (cb[[k]] > 0) 100 * (cm[[k]] / cb[[k]] - 1) else NA))
  cat(sprintf("   J/J* - 1      mr %+.3e  bnd %+.3e  (bound max(2 x bnd, 0.01 eps) = %.3e)\n",
              mr$J / J_star[[s]] - 1, bnd$J / J_star[[s]] - 1,
              max(2 * abs(bnd$J / J_star[[s]] - 1), 0.01 * eps_of("ln J"))))

  ref <- readRDS(ref_file[[s]])$stand$elasticity[paste0("1.", traits)]
  pl <- readRDS(file.path(D, "phase1c/combined/full", sprintf("bnd_%s.rds", s)))$stand$elasticity[paste0("1.", traits)]
  e <- vapply(traits, eps_of, 0)
  Em <- frozen(sprintf("el_%s_mr", s)); Eb <- frozen(sprintf("el_%s_bnd", s))
  cat("\n   resident elasticities; distances in eps (each floored at 0.01)\n")
  cat(sprintf("   %-6s %10s %10s %10s %10s | %8s %8s %8s %8s\n", "trait", "1e-5 ref", "mr fz", "bnd fz",
              "bnd plant", "mr-ref", "bnd-ref", "gap", "mr-bnd"))
  for (i in seq_along(traits)) {
    cat(sprintf("   %-6s %10.5f %10.5f %10.5f %10.5f | %+8.3f %+8.3f %+8.3f %+8.3f\n", traits[i], ref[i], Em[i], Eb[i],
                pl[i], (Em[i] - ref[i]) / e[i], (Eb[i] - ref[i]) / e[i], (Eb[i] - pl[i]) / e[i], (Em[i] - Eb[i]) / e[i]))
  }
  ok <- is.finite(Em) & is.finite(Eb)
  if (any(ok)) {
    dm <- abs(Em - ref) / e; db <- abs(Eb - ref) / e
    cat(sprintf("   largest |mr - ref| %.3f eps (%s); under eps/3: %s; within bnd's + 0.1 eps on every trait: %s (%d of %d traits measured)\n",
                max(dm[ok]), traits[ok][which.max(dm[ok])], all(dm[ok] < 1 / 3), all(dm[ok] <= db[ok] + 0.1),
                sum(ok), length(traits)))
  }
  if (s == "ld") {
    u4 <- frozen("el_ld_mr", 1e-4, "_u4")
    if (any(is.finite(u4))) {
      cat("   r = 1e-4 against r = 1e-3 on mr (unfrozen soil sub-steps), in eps:",
          paste(sprintf("%s %+.4f", traits[is.finite(u4)], ((u4 - Em) / e)[is.finite(u4)]), collapse = ", "), "\n")
    }
    lad <- lapply(c("1e-4", "3e-5", "1e-5"), function(t) if (t == "3e-5") mr else run(sprintf("mr_ld_%s", t)))
    if (all(!vapply(lad, is.null, TRUE))) {
      eJ <- vapply(lad, function(x) x$J / J_star[["ld"]] - 1, 0)
      cat(sprintf("   mr's J over 1e-4, 3e-5, 1e-5: J/J* - 1 = %s; rows %s\n",
                  paste(sprintf("%+.3e", eJ), collapse = ", "),
                  paste(vapply(lad, function(x) sprintf("%.0f", sum(x$st$M)), ""), collapse = ", ")))
    }
    nd <- lapply(c("2.85e-5", "3.15e-5"), function(t) run(sprintf("mr_ld_%s", t)))
    if (all(!vapply(nd, is.null, TRUE))) {
      cat(sprintf("   mr's +-5%% nudges: ln J moves %s eps; rows %s\n",
                  paste(sprintf("%+.4f", vapply(nd, function(x) log(x$J / mr$J), 0) / eps_of("ln J")), collapse = ", "),
                  paste(vapply(nd, function(x) sprintf("%.0f", sum(x$st$M)), ""), collapse = ", ")))
    }
  }
  cat("\n")
}
