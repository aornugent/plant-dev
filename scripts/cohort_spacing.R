# The transport stencil's divisor: cohort spacing on the real grid, including the
# boundary interval to new_node, which is where the staggering's one degenerate case is.
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-develop", quiet=TRUE)})
p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
p$max_patch_lifetime <- 105.32
scm <- SCM("TF24","TF24_Env")(p, Environment("TF24"), Control())
scm$collect <- TRUE; scm$run()
hist <- scm$history

interior <- c(); boundary <- c(); zero_b <- 0L; nsnap <- 0L; rec <- list()
for (pa in hist) {
  sp <- pa$species[[1]]; n <- sp$size; if (n < 1) next
  h  <- sp$heights                       # descending
  h0 <- sp$new_node$height
  nsnap <- nsnap + 1L
  db <- h[n] - h0                        # the boundary interval: last cohort down to height_0
  boundary <- c(boundary, db); if (db == 0) zero_b <- zero_b + 1L
  if (n >= 2) interior <- c(interior, -diff(h))   # descending, so -diff is positive
  rec[[nsnap]] <- data.frame(time=pa$time, n=n, dh_boundary=db,
                            dh_int_min=if (n>=2) min(-diff(h)) else NA_real_)
}
d <- do.call(rbind, rec)
q <- function(v) sprintf("min %.4e  p1 %.4e  median %.4e  max %.4e", min(v), quantile(v,.01), median(v), max(v))
cat("=== cohort spacing on the real grid, ", nsnap, " snapshots\n", sep="")
cat("interior intervals (n=", length(interior), "): ", q(interior), "\n", sep="")
cat("boundary interval  (n=", length(boundary), "): ", q(boundary), "\n", sep="")
cat(sprintf("\nboundary interval EXACTLY zero: %d / %d snapshots\n", zero_b, nsnap))
cat(sprintf("boundary interval < 1e-8:       %d\n", sum(boundary < 1e-8)))
cat(sprintf("boundary interval < 1e-4:       %d\n", sum(boundary < 1e-4)))
cat(sprintf("interior  interval < 1e-8:      %d / %d\n", sum(interior < 1e-8), length(interior)))
cat(sprintf("interior  interval < 1e-4:      %d\n", sum(interior < 1e-4)))
cat(sprintf("\nreport 01 s7.6's toy minimum was 3.7e-02; the real interior minimum is %.4e\n", min(interior)))
cat("\n=== the smallest boundary intervals, with time and cohort count\n")
print(utils::head(d[order(d$dh_boundary), c("time","n","dh_boundary","dh_int_min")], 8), row.names=FALSE)
