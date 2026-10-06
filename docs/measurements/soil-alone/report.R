# The soil-alone spikes (prereg.txt): each variant's cost and J against mrw's and bounded
# Cash-Karp's (bnd), on long drought, episodic and the constant record.
#   DEV=... Rscript report.R
D <- Sys.getenv("DEV")
S <- file.path(D, "soil_alone", "runs")
run <- function(f) if (file.exists(f)) readRDS(f)
here_run <- function(name) run(file.path(S, paste0(name, ".rds")))
# Q3's records: bnd and mrw at 3e-5 on 108 uniform introductions.
q3 <- list(
  "long-drought" = list(bnd = run(file.path(D, "pf_soil/runs/q1_ld.rds")),
                        mrw = run(file.path(D, "pf_soil/mr/runs/mrw_ld.rds"))),
  episodic = list(bnd = run(file.path(D, "pf_soil/runs/q1_epi.rds")),
                  mrw = run(file.path(D, "pf_soil/mr/runs/mrw_epi.rds"))))
J_star <- c("long-drought" = 12.6687135, episodic = 1.978902094, constant = 289.273896201)
eps_lnJ <- 0.0252373006179605
rows <- function(x) sum(x$st$M)
cost <- function(x) c(rows = rows(x), steps = x$counts$accepted,
                      rejected = x$counts$rejected_inaccurate,
                      evaluations = x$counts$evaluations, members = x$counts$members,
                      flagged = if (is.null(x$mr)) 0 else sum(x$mr),
                      substeps = if (is.null(x$mr)) 0 else x$counts$chain_substeps)
eJ <- function(x, rec) x$J / J_star[[rec]] - 1
show <- function(rec, arms) {
  arms <- Filter(Negate(is.null), arms)
  if (!length(arms)) return(invisible())
  base <- arms[[1]]
  cat(sprintf("== %s (against %s)\n", rec, names(arms)[1]))
  cat(sprintf("   %-12s %s\n", "", paste(sprintf("%22s", names(arms)), collapse = "")))
  cb <- cost(base)
  for (k in names(cb)) {
    cat(sprintf("   %-12s %s\n", k, paste(vapply(arms, function(x) {
      v <- cost(x)[[k]]
      if (identical(x, base) || cb[[k]] == 0) sprintf("%22.0f", v)
      else sprintf("%12.0f (%+6.1f%%)", v, 100 * (v / cb[[k]] - 1))
    }, ""), collapse = "")))
  }
  bound <- if (!is.null(arms$bnd)) max(2 * abs(eJ(arms$bnd, rec)), 0.01 * eps_lnJ) else NA
  cat(sprintf("   %-12s %s\n", "J/J* - 1", paste(sprintf("%22.3e", vapply(arms, eJ, 0, rec)),
                                                   collapse = "")))
  cat(sprintf("   bound max(2 |bnd|, 0.01 eps) = %.3e\n", bound))
}
for (rec in c("long-drought", "episodic")) {
  show(rec, list(bnd = q3[[rec]]$bnd, mrw = q3[[rec]]$mrw,
                 s1 = here_run(paste0("s1_", rec)), s2 = here_run(paste0("s2_", rec)),
                 s12 = here_run(paste0("s12_", rec))))
}
cat("== long drought, S12 over the tolerance ladder: J/J* - 1 and rows\n")
for (tol in c("1e-4", "3e-5", "1e-5")) {
  x <- if (tol == "3e-5") here_run("s12_long-drought") else here_run(paste0("s12_long-drought_", tol))
  if (!is.null(x)) cat(sprintf("   %-6s %+.3e  rows %.0f\n", tol, eJ(x, "long-drought"), rows(x)))
}
show("constant", list(bnd = here_run("bnd_constant"), mrw = here_run("mrw_constant"),
                      s2 = here_run("s2_constant"), s12 = here_run("s12_constant"),
                      arkc = here_run("arkc_constant")))
cat("JOB DONE report.R\n")
