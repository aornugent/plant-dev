# score.R: every lean run (and the existing runs on the same schedule) against the
# stopped 3e-5 reference, and each nudge pair's move, in eps (round4/JT/nudge.R's
# quantities). Prints the tables results.md quotes; saves deep/lean/score.rds.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean"
REF <- Sys.getenv("REF", "L1_ref_3e-5_stop")
src <- list(A = "P_out/runs/P_ins3c_dry", B = "X_out/runs/X_ins3c_2.85e-4_dry",
  `JT8_3e-4` = "JT_out/JT8_ins_3e-4_stop", `JT8_2.85e-4` = "JT_out/JT8_ins_2.85e-4_stop",
  `JT10_3e-4` = "JT_out/JT10_ins_3e-4_h05", `JT10_2.85e-4` = "JT_out/JT10_ins_2.85e-4_h05")
logs <- c(`JT8_3e-4` = "JT8_ins_3e-4_stop", `JT8_2.85e-4` = "JT8_ins_2.85e-4_stop", `JT10_3e-4` = "JT10_ins_3e-4_h05", `JT10_2.85e-4` = "JT10_ins_2.85e-4_h05")
rd <- function(n) { f <- if (!is.null(src[[n]])) file.path(S, paste0(src[[n]], ".rds")) else file.path(O, paste0(n, ".rds"))
  if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
cuts <- function(n) { f <- if (n %in% names(logs)) file.path(S, "adjmap/logs", paste0(logs[[n]], ".log")) else file.path(O, paste0(n, ".log"))
  if (!file.exists(f)) return(NA); l <- grep("^JTCUT", readLines(f), value = TRUE)
  t0 <- as.numeric(vapply(strsplit(l, " "), `[`, "", 3)); c(n = length(l), before25 = sum(t0 <= 25)) }
names_all <- c(REF, names(src), sub("\\.rds$", "", list.files(O, "^(L[123]|X[123])_.*\\.rds$")))
names_all <- unique(names_all[!grepl("^L3_rank", names_all)])
runs <- Filter(Negate(is.null), setNames(lapply(names_all, rd), names_all))
ref <- quantities(runs[[REF]])
U1 <- runs[["L1_1e-4_none"]]$stand$rows; U3 <- runs[["A"]]$stand$rows
tab <- do.call(rbind, lapply(names(runs), function(n) { x <- runs[[n]]; q <- quantities(x); k <- intersect(names(q), names(ref)); e <- (q[k] - ref[k]) / eps_vec(k)
  el <- e[k != "lnJ"]; cc <- cuts(n)
  data.frame(run = n, tol = x$setting$tol, rms_el = sqrt(mean(el^2)), max_el = max(abs(el)), max_at = names(el)[which.max(abs(el))], lnJ = e[["lnJ"]],
    steps = length(x$stand$times), rows = x$stand$rows, rows_u1e4 = if (is.null(U1)) NA else x$stand$rows / U1, rows_u3e4 = x$stand$rows / U3,
    fwd = x$stand$cpu, sweep = x$sweep_cpu, cuts = cc[1], cuts_b25 = if (length(cc) > 1) cc[2] else NA) }))
options(width = 220)
cat("Against", REF, "(eps; rms and max over elasticities):\n"); print(tab, digits = 3, row.names = FALSE)
pairs <- list(c("A", "B"), c("JT8_3e-4", "JT8_2.85e-4"), c("JT10_3e-4", "JT10_2.85e-4"), c("L1_1e-3_stop", "L1_9.5e-4_stop"),
  c("L2_h025_3e-4", "L2_h025_2.85e-4"), c("L2_t25_3e-4", "L2_t25_2.85e-4"), c("L2_both_3e-4", "L2_both_2.85e-4"),
  c("L3_b10_A", "L3_b10_B"), c("L3_b30_A", "L3_b30_B"), c("L3_l30_A", "L3_l30_B"), c("L3_b50_A", "L3_b50_B"), c("X1_both_1.5e-4", "X1_both_1.425e-4"), c("X1_both_1e-4", "X1_both_9.5e-5"), c("X2_stop_1e-4", "X2_stop_9.5e-5"), c("X2_t25_1e-4", "X2_t25_9.5e-5"), c("L1_ref_3e-5_stop", "X3_ref_2.85e-5_stop"), c("L1_1e-4_none", "X3_9.5e-5_none"))
nud <- do.call(rbind, lapply(pairs, function(p) { if (!all(p %in% names(runs))) return(NULL); qx <- quantities(runs[[p[1]]]); qy <- quantities(runs[[p[2]]]); k <- intersect(names(qx), names(qy))
  d <- (qy[k] - qx[k]) / eps_vec(k); el <- d[k != "lnJ"]
  data.frame(pair = paste(p, collapse = " -> "), rms = sqrt(mean(d^2)), rms_el = sqrt(mean(el^2)), max = max(abs(d)), max_at = k[which.max(abs(d))],
    cost_scale = d[grep("TF24_cost_scale", k)[1]], rows = runs[[p[1]]]$stand$rows, rows_u3e4 = runs[[p[1]]]$stand$rows / U3) }))
cat("\nNudges (B - A, eps; rms over all quantities as nudge.R, and over elasticities):\n"); print(nud, digits = 3, row.names = FALSE)
saveRDS(list(tab = tab, nudge = nud), file.path(O, "score.rds"))
