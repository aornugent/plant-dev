# collect.R: every completed gradient run of this round into summary.rds, in the H5 round's
# schema (`../h5/notes.md`, "summary.rds"). Layout rules: U (tcut 10); Uxh / Ufh, Uxw / Ufw
# (hybrids: U16 / U06 with the S* stretches, or the wide ones only, laid out as U10); V (U with
# every stretch at least W days wide given at least ceiling(n0 / s) intervals).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
FIX <- list(n0 = as.numeric(Sys.getenv("FIX_N0", "NA")), W = as.numeric(Sys.getenv("FIX_W", "NA")))
lay <- function(kind) { s <- NA; role <- "ladder"; rule <- sub("[0-9].*$", "", kind)
  if (grepl("^[UV][0-9]{2}$", kind)) s <- SK[[substr(kind, 2, 3)]]
  if (kind %in% c("Uxh", "Uxw")) { s <- 1.6; role <- paste("hybrid", kind) }; if (kind %in% c("Ufh", "Ufw")) { s <- 1 / 1.6; role <- paste("hybrid", kind) }
  data.frame(kind = kind, rule = rule, s = s, open = "node1", d_o = 0, tcut = 10, close = "node at c and c - 12 d (before tcut; E6 inset after)", strip_days = 12, tol = 1e-4, role = role,
    n0 = if (rule == "V") FIX$n0 else 0, W = if (rule == "V") FIX$W else Inf) }
fs <- list.files(file.path(UOUT, "runs"), "^h5_.*\\.rds$"); RW <- list(); QL <- list(); NODES <- list()
for (f in fs) { nm <- sub("\\.rds$", "", f); x <- readRDS(file.path(UOUT, "runs", f)); if (is.null(x$stand$elasticity)) next
  cs <- sub("^h5_[^_]+_", "", nm); kind <- sub("^h5_", "", sub(paste0("_", cs, "$"), "", nm)); ref <- ref5(cs); e <- err_of(x, ref); qv <- quantities(x)[names(e)]
  RW[[nm]] <- cbind(data.frame(name = nm, case = cs), lay(kind), data.frame(n_nodes = length(x$node_times), rows = rows_of(x), cpu = cpu_of(x), steps = steps_of(x),
    proxy = alg$proxy_err(pilot_of(cs), sort(x$node_times)), worst = max(abs(e)), worst_q = names(e)[which.max(abs(e))], rms = r2(e), along_M = onM(e), lnJ = unname(qv["lnJ"])))
  QL[[nm]] <- data.frame(name = nm, case = cs, quantity = names(e), cls = cls(names(e)), value = unname(qv), ref = unname(ref[names(e)]), eps = unname(eps_vec(names(e))), err = unname(e))
  NODES[[nm]] <- sort(x$node_times) }
S <- list(runs = do.call(rbind, RW), q = do.call(rbind, QL), nodes = NODES, updated = format(Sys.time()),
  schema = "runs: one row per gradient run (layout: rule U = opening node, closing node + c - 12 d before tcut = 10, E6's 12-d inset after; Uxh/Ufh, Uxw/Ufw = hybrids (U16/U06 with S* or wide S* stretches laid out as U10); V = U with every stretch >= W days given >= ceiling(n0/s) intervals; s spacing scale; tol; n_nodes, rows (run_cost), cpu, steps, proxy (a09 proxy_err), worst/rms/along_M error in eps vs lib19-class reference). q: long table name x quantity: value, ref, eps, err = (value - ref)/eps. nodes: node_times per run (years).")
rownames(S$runs) <- NULL; rownames(S$q) <- NULL
saveRDS(S, file.path(UOUT, "summary.rds")); cat(sprintf("summary.rds: %d runs, %d quantity rows\n", nrow(S$runs), nrow(S$q)))
