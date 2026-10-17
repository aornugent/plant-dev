# collect.R: every completed gradient run of this round into summary.rds (schema in notes.md).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
lay <- function(kind) { base <- sub("@.*", "", kind); tol <- if (grepl("@jit", kind)) 1.05e-4 else 1e-4
  s <- NA; open <- NA; d_o <- NA; tcut <- 25; role <- "ladder"; rule <- substr(base, 1, 1)
  if (grepl("^oin", base)) { s <- 1; open <- "inset"; d_o <- as.numeric(sub("oin", "", base)); role <- "opening ladder"; rule <- "O" }
  else if (base == "ores") { s <- 1; open <- "resolved"; role <- "opening reference"; rule <- "O" }
  else if (grepl("^[NSMTC][0-9]{2}", base)) { s <- c("20" = 2, "16" = 1.6, "10" = 1, "06" = 1 / 1.6)[[substr(base, 2, 3)]]
    open <- c(N = "node", S = "inset", M = "node1", T = "node1", C = "inset")[[rule]]
    d_o <- c(N = 12, S = 12 * s, M = 0, T = 0, C = 12)[[rule]]; if (rule == "T") tcut <- 17
    if (nchar(base) > 3) role <- paste("strip refinement", substring(base, 4)) }
  data.frame(kind = kind, rule = rule, s = s, open = open, d_o = d_o, tcut = tcut, close = "node at c and c - 12 d (before tcut; E6 inset after)", strip_days = 12, tol = tol, role = role) }
fs <- list.files(file.path(H5, "runs"), "^h5_.*\\.rds$"); RW <- list(); QL <- list(); NODES <- list()
for (f in fs) { nm <- sub("\\.rds$", "", f); x <- readRDS(file.path(H5, "runs", f)); if (is.null(x$stand$elasticity)) next
  cs <- sub("^h5_[^_]+_", "", nm); kind <- sub("^h5_", "", sub(paste0("_", cs, "$"), "", nm)); ref <- ref5(cs); e <- err_of(x, ref); qv <- quantities(x)[names(e)]
  RW[[nm]] <- cbind(data.frame(name = nm, case = cs), lay(kind), data.frame(n_nodes = length(x$node_times), rows = rows_of(x), cpu = cpu_of(x), steps = steps_of(x),
    proxy = alg$proxy_err(pilot_of(cs), sort(x$node_times)), worst = max(abs(e)), worst_q = names(e)[which.max(abs(e))], rms = r2(e), along_M = onM(e), lnJ = unname(qv["lnJ"])))
  QL[[nm]] <- data.frame(name = nm, case = cs, quantity = names(e), cls = cls(names(e)), value = unname(qv), ref = unname(ref[names(e)]), eps = unname(eps_vec(names(e))), err = unname(e))
  NODES[[nm]] <- sort(x$node_times) }
S <- list(runs = do.call(rbind, RW), q = do.call(rbind, QL), nodes = NODES, updated = format(Sys.time()),
  schema = "runs: one row per gradient run (layout: rule N = opening node + fixed o+12 d; M = opening node only (node1); T = M with E6 inset for edges at b >= tcut = 17; C = opening inset fixed 12 d; S = opening inset 12 s; O = opening-step runs; s spacing scale; tol; n_nodes, rows (run_cost), cpu, steps, proxy (a09 proxy_err), worst/rms/along_M error in eps vs lib19-class reference). q: long table name x quantity: value, ref, eps, err = (value - ref)/eps. nodes: node_times per run (years).")
rownames(S$runs) <- NULL; rownames(S$q) <- NULL
saveRDS(S, file.path(H5, "summary.rds")); cat(sprintf("summary.rds: %d runs, %d quantity rows\n", nrow(S$runs), nrow(S$q)))
