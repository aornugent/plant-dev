# common.R: the inventory (inv.R) with each run's quantities, its build class, and its
# error against the reference of its own build, in eps units.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
INV <- readRDS(file.path(OUT, "inv.rds")); TAB <- INV$tab; RR <- INV$runs
ALL <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
# lib, lib18 and lib19 give bit-identical runs on identical schedules and settings
# (checked in q1.R: val_c5t/val_probe_noedge25, fx_a04t/val_a04t, val_a09h/val_a09g).
TAB$build <- ifelse(TAB$lib %in% c("lib", "lib18", "lib19", "libS", "libR", "lib_base", "lib_114"), "L19",
  ifelse(TAB$lib %in% c("libS+k0", "libR+k0"), "S", ifelse(TAB$lib == "libAG", "AG", TAB$lib)))
# Older runs moved a trait without recording TRAIT_REL; their names carry it.
moved <- TAB$trait == "" & grepl("lma|p50|P50|a_dG2|_th0b?_?[a-z]*$", TAB$name) & !grepl("^m_th0_|th0_", TAB$name)
TAB$case[moved] <- NA
TAB$case[TAB$name %in% c("m_lma1252_episodic", "m_lma1254_episodic", "m_lma125_episodic", "inv_C_dylma_episodic", "inv_H_dylma_episodic")] <- "episodic-lma"
# Runs with the rain's knot stops removed on a knot-stopping build (E's defect probe), or
# a silent gradient blow-up of the legacy long-drought setting (round 3 D).
TAB$bad <- TAB$name %in% c("E_k0_dry", "E_k0f5_dry", "E_k25_dry", "G_k25_c_dry", "G_k25w10_c_dry") | grepl("^val_a10s_|^val_a10n1", TAB$name)
TAB$legacy <-TAB$split %in% c("0", "")   # long-drought records' old setting (no soil share, no splits)
qof <- function(id) { r <- RR[[id]]; if (is.null(r$el)) return(NULL); quantities(list(stand = list(J = r$J, elasticity = r$el))) }
Q <- names(qof("schedtest/adjmap/runs/val_a09_c_dry"))
EPS <- eps_vec(Q)
byname <- function(nm, dir = NULL) { i <- which(TAB$name == nm & (is.null(dir) | grepl(if (is.null(dir)) "" else dir, TAB$dir))); if (!length(i)) stop("no run ", nm); TAB$id[i[1]] }
qn <- function(nm) qof(byname(nm))
# References: lib19-class as the harness (training) and F (held-out); libAG as AG.
REF <- list(L19 = list(), AG = list())
for (cs in ALL) REF$L19[[cs]] <- if (!is.null(CASES[[cs]])) reference(cs) else {
  x <- qn(sprintf("ref_%s_u215", cs)); y <- qn(sprintf("ref_%s_u429", cs)); k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
for (cs in c("dry", "long-drought", "episodic-lma")) {
  x <- qn(sprintf("AG_ref_%s_u215", cs)); y <- qn(sprintf("AG_ref_%s_u429", cs)); k <- intersect(names(x), names(y)); REF$AG[[cs]] <- extrap(x[k], y[k]) }
# The runs that make a reference are not scored against it.
REF_RUNS <- c(basename(unlist(REF_FILES)), sprintf("ref_%s_u%d.rds", rep(c("dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2"), each = 2), c(215, 429)),
  sprintf("AG_ref_%s_u%d.rds", rep(c("dry", "long-drought", "episodic-lma"), each = 2), c(215, 429)))
TAB$isref <- paste0(TAB$name, ".rds") %in% REF_RUNS
# Error of a run in eps units against its build's reference (S runs scored on L19's,
# with the build offset noted where used).
err_of <- function(id, build = TAB$build[TAB$id == id], case = TAB$case[TAB$id == id]) {
  rb <- if (build == "AG") "AG" else "L19"; ref <- REF[[rb]][[case]]; if (is.null(ref)) return(NULL)
  q <- qof(id); if (is.null(q)) return(NULL); k <- intersect(Q, intersect(names(q), names(ref))); (q[k] - ref[k]) / EPS[k] }
# Pilot data per case.
PIL <- list(); for (cs in ALL) PIL[[cs]] <- tryCatch({ p <- pilot_edges(cs); p$cr <- as.data.frame(readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand$creation); p }, error = function(e) NULL)
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a09_late.R", alg)
pilot_ctx <- function(cs) { pe <- PIL[[cs]]; px <- readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]), J = px$J, creation = as.data.frame(px$creation)) }
# Hydraulic direction M (P: lib19 in10 move on dry), unit length.
M_raw <- { a <- qn("P_in10_dry"); b <- qof("schedtest/adjmap/runs/val_a09_c_dry"); (a[Q] - b[Q]) / EPS }
M_unit <- M_raw / sqrt(sum(M_raw^2))
