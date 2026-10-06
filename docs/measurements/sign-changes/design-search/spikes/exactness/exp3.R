# lnJ's error against tol for each method, each on its own adaptive mesh.
source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
for (m in strsplit(Sys.getenv("METHODS", "plain,smooth,bracket,split"), ",")[[1]]) {
  for (tol in c(1e-3, 3e-4, 1e-4, 3e-5, 1e-5)) {
    reset_counts()
    a <- run_adaptive(th0, tol, m)
    cat(sprintf("%s %g steps %d evals %d lnJ %.12f corrected %d split %d Kmax_far %.3g\n", m, tol,
                length(a$times) - 1, CNT$evals, lnJ_of(a$y), CNT$corr, CNT$split, CNT$Kmax_far))
    flush.console()
  }
}
