# l3_pins.R: rank A's switch steps by part 4's bound (theta/J/eps)|lambda_soil| h |dG| 0.2
# (P4_G_A) and by |lambda_soil| alone; for the top k, pins of A and B on their own steps
# with step ends at each chosen step's first and last f_hi root (A's detection log),
# boundaries strictly between them dropped, as mkstops.R does for one window. Unlike
# mkstops.R, a dropped boundary may end a substepped step: the merged step and the pieces
# beside each new end replay without soil substeps (counted as lost_substeps).
JT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
S <- dirname(JT)
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean"
G <- readRDS(file.path(JT, "P4_G_A.rds"))
x <- readRDS(file.path(JT, "P4_lam_A.rds")); sc <- x$theta[names(x$gradient) == "1.TF24_cost_scale"] / x$J / 0.0196115
G$bound <- sc * abs(G$lam1) * G$h_d / 365 * abs(G$dG1) * 0.2
L <- grep("^JTROOT", readLines(file.path(JT, "P4_traj_A.err")), value = TRUE)
r <- as.data.frame(do.call(rbind, lapply(strsplit(L, " "), function(z) { v <- z[-1]; setNames(as.numeric(v[seq(2, length(v), 2)]), v[seq(1, length(v), 2)]) })))
r$t <- r$t0 + r$u * r$h
roots <- function(t0) { z <- r$t[abs(r$t0 - t0) < 1e-9 * max(1, t0)]; c(min(z), max(z)) }
pins <- list(A = file.path(S, "P_out/runs/P_ins3c_dry.rds"), B = file.path(S, "X_out/runs/X_ins3c_2.85e-4_dry.rds"))
mkpin <- function(pin, win, out) {
  s <- readRDS(pin)$stand; tt <- s$times
  inside <- Reduce(`|`, lapply(seq_len(nrow(win)), function(i) tt > win[i, 1] - 1e-9 & tt < win[i, 2] + 1e-9))
  nt <- sort(c(tt[!inside], unique(c(win)))); idx <- match(nt, tt)
  sz <- c(s$sizes[1], diff(nt)); old <- !is.na(idx) & c(FALSE, !is.na(idx[-1]) & !is.na(idx[-length(idx)]))
  sz[old] <- s$sizes[idx[old]]
  carry <- function(v) lapply(seq_along(nt), function(i) if (is.na(idx[i]) || (i > 1 && is.na(idx[i - 1]))) numeric(0) else v[[idx[i]]])
  saveRDS(list(stand = list(times = nt, sizes = sz, input_slopes = carry(s$input_slopes), substep_ends = carry(s$substep_ends))), out)
  c(added = length(nt) - length(tt), dropped = sum(inside), dropped_substepped = sum(lengths(s$input_slopes[inside]) > 0), lost_substeps = sum(lengths(s$input_slopes) > 0) - sum(lengths(carry(s$input_slopes)) > 0))
}
cfg <- list(b10 = order(-G$bound)[1:10], b30 = order(-G$bound)[1:30], b50 = order(-G$bound)[1:50], l30 = order(-abs(G$lam1))[1:30])
tab <- NULL
for (nm in names(cfg)) {
  win <- t(vapply(G$t0[cfg[[nm]]], roots, numeric(2)))
  for (run in names(pins)) {
    z <- mkpin(pins[[run]], win, file.path(O, sprintf("pin_L3_%s_%s.rds", nm, run)))
    tab <- rbind(tab, data.frame(cfg = nm, run = run, ends = length(unique(c(win))), t(z), share_c = sum(abs(G$c_soil[cfg[[nm]]])) / sum(abs(G$c_soil))))
  }
}
saveRDS(list(G = G, cfg = cfg), file.path(O, "L3_rank.rds"))
print(tab, digits = 3)
