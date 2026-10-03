# How good the reference is over a test step: from the reference's state at a
# test start, fixed Cash-Karp sub-steps of at most 0.05 and 0.1 day inside each
# resident step, to each test step's end, against the reference pass (adaptive
# at RTOL). Per state: the largest relative difference (mortality absolute, the
# pool against its capacity, offspring as its increment over the step).
#   PLANT_LIB=$DEV/lib_guard [REC=ld_ruleA] [PASS1=pass1_ld_ruleA.rds] [STARTS=1,12,...] \
#     Rscript refcheck.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
P1 <- readRDS(file.path(S, Sys.getenv("PASS1", paste0("pass1_", REC, ".rds"))))
key <- function(t) sprintf("%.10f", t)
H <- P1$h_days
idx <- if (nzchar(Sys.getenv("STARTS"))) as.integer(strsplit(Sys.getenv("STARTS"), ",")[[1]]) else
  unique(round(seq(1, nrow(P1$starts), length.out = 6)))
diffs <- function(Ya, Yb, Y0) {
  out <- matrix(0, 0, 7, dimnames = list(NULL, STATE))
  for (i in seq_along(Ya)) {
    M <- ncol(Y0[[i]])
    if (M == 0) next
    a <- Ya[[i]][, seq_len(M), drop = FALSE]; b <- Yb[[i]][, seq_len(M), drop = FALSE]
    d <- abs(a - b) / abs(b)
    d[I_MORT, ] <- abs(a[I_MORT, ] - b[I_MORT, ])
    d[I_STORE, ] <- abs(a[I_STORE, ] - b[I_STORE, ]) / capacity(i, b[1, ])
    d[I_OFF, ] <- abs(a[I_OFF, ] - b[I_OFF, ]) / abs(b[I_OFF, ] - Y0[[i]][I_OFF, ])
    out <- rbind(out, t(d))
  }
  apply(out, 2, max)
}
for (si in idx) {
  t0 <- P1$starts$t0[si]
  Y0 <- P1$saved[[key(t0)]]
  for (i in seq_along(INV)) {
    M <- ncol(Y0[[i]])
    reset_invader(i, P1$members[[i]]$birth[seq_len(M)], P1$members[[i]]$node[seq_len(M)])
  }
  outs <- t0 + H * DAY
  f05 <- ck_fixed(t0, Y0, outs, 0.05 * DAY)
  f10 <- ck_fixed(t0, Y0, outs, 0.1 * DAY)
  for (hd in H) {
    k <- key(t0 + hd * DAY)
    cat(sprintf("t0 %.5f h %2g d | adaptive vs 0.05 d: %s | 0.1 d vs 0.05 d: %s\n", t0, hd,
                paste(sprintf("%.1e", diffs(P1$saved[[k]], f05[[k]], Y0)), collapse = " "),
                paste(sprintf("%.1e", diffs(f10[[k]], f05[[k]], Y0)), collapse = " ")))
  }
}
cat("columns:", paste(STATE, collapse = " "), "\n")
