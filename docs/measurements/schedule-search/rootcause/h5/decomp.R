source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
for (cs in commandArgs(TRUE)) { et <- edge_table(cs); ce <- et$b[!et$opening]; oe <- et$b[et$opening]
  cat_of <- function(S) { near <- function(v) sapply(S, function(x) any(abs(v - x) < 1e-7))
    c(n = length(S), close_edge = sum(near(ce)), c_m12 = sum(near(ce - 12 * D)), open_edge = sum(near(oe)), o_p12 = sum(near(oe + 12 * D)), bg_lt25 = sum(S < 25) - sum(near(c(ce, ce - 12 * D, oe, oe + 12 * D))), ge25 = sum(S >= 25)) }
  E6 <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs)))
  V <- list(E6 = E6, N = h5_sched(cs, 1, "node"), N1 = h5_sched(cs, 1, "node1"), C_oin12 = h5_sched(cs, 1, "inset", d_o = 12),
    N_t17 = h5_sched(cs, 1, "node", tcut = 17), N1_t17 = h5_sched(cs, 1, "node1", tcut = 17), N1_t10 = h5_sched(cs, 1, "node1", tcut = 10))
  cat("\n==", cs, " closing edges", length(ce), "(>=17:", sum(ce >= 17), ") opening", length(oe), "\n"); print(t(sapply(V, cat_of)))
  for (k in c("N", "N1", "N1_t17")) { n <- sapply(c(2, 1.6, 1, 1/1.6), function(s) length(h5_sched(cs, s, if (grepl("N1", k)) "node1" else "node", tcut = if (grepl("t17", k)) 17 else 25)))
    w <- sapply(c(2, 1.6, 1, 1/1.6), function(s) { S <- h5_sched(cs, s, "node"); d <- diff(S) * 365; m <- (head(S, -1) + S[-1]) / 2; op <- pilot_of(cs)$shut(m) < 0.5; c(max(d[op & m < 20]), max(d[op & m >= 20 & m < 25]), max(d[op & m >= 25])) })
    cat(sprintf("  %-7s nodes s=2/1.6/1/0.625: %s\n", k, paste(n, collapse = "/"))) }
  cat("  widest open interval (d) by s=2/1.6/1/0.625 (N): b<20 ", paste(round(w[1, ]), collapse = "/"), " | 20-25 ", paste(round(w[2, ]), collapse = "/"), " | >25 ", paste(round(w[3, ]), collapse = "/"), "\n") }
