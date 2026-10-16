# Shared loaders for the closing-edge round: the inventory's references and M, P's edge
# tables and inset rule, and per-run scoring of runs read straight from their files.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R"))
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
CL <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/closing"
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
H1R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1/runs"
run_file <- function(nm) { for (d in c(file.path(CL, "runs"), ADJ, H1R, file.path(POUT, "runs"))) { f <- file.path(d, paste0(nm, ".rds")); if (file.exists(f)) return(f) }; stop("no run ", nm) }
rd <- function(nm) readRDS(run_file(nm))
# Error of a run (eps units) against the lib19-class reference of its case.
err_run <- function(x, cs) { q <- quantities(x); ref <- REF$L19[[cs]]; k <- intersect(Q, intersect(names(q), names(ref))); (q[k] - ref[k]) / EPS[k] }
mv_run <- function(x, y) { a <- quantities(x); b <- quantities(y); k <- intersect(Q, intersect(names(a), names(b))); (a[k] - b[k]) / EPS[k] }
onM <- function(e) { m <- M_unit[names(e)]; m[is.na(m)] <- 0; sum(e * m) }
offM <- function(e) { m <- M_unit[names(e)]; m[is.na(m)] <- 0; sqrt(mean((e - sum(e * m) * m)^2)) }
r2 <- function(x) sqrt(mean(x^2))
# Closing edges before 25 with the inset schedule's two nodes around each: the spell's
# last node inside (lo) and the first node after the gap (hi), and the one before lo.
closing_anatomy <- function(S, cs) { et <- edge_table(cs); et <- et[!et$opening, ]; S <- sort(S)
  do.call(rbind, lapply(seq_len(nrow(et)), function(i) { c0 <- et$b[i]; j <- max(which(S < c0)); data.frame(edge = c0, spell = et$spell[i], gap = et$gap[i],
    d_in = (c0 - S[j]) * 365, h_end = if (j > 1) (S[j] - S[j - 1]) * 365 else NA, h_gap = (S[j + 1] - S[j]) * 365, j = j) })) }
HYD <- c("a_l1", "root_P50", "omega", "root_c", "stem_c", "storage_relaxation_offset"); LEAF <- c("a", "curv_fact_elec_trans", "k_I", "jmax_25", "lma", "vcmax_25", "R_d_25")
# One line for a vector of eps-unit errors or moves; with base, its share of base's squared size by projection.
fmt <- function(x, base = NULL) { top <- names(x)[order(-abs(x))][1:4]
  sprintf("rms %.3f | M %+.2f off %.3f | leaf rms %.3f hyd rms %.3f | lnJ %+.3f%s | %s", r2(x), onM(x), offM(x), r2(x[intersect(LEAF, names(x))]), r2(x[intersect(HYD, names(x))]), x["lnJ"],
    if (is.null(base)) "" else sprintf(" | share %3.0f%%", 100 * sum(x * base[names(x)]) / sum(base^2)), paste(sprintf("%s %+.2f", top, x[top]), collapse = ", ")) }
# The case's daily rain record (mm), as mkenv() lays it out.
rain_rec <- function(cs) { e <- new.env(); src <- readLines("/home/user/plant-dev/harness/long_drought.R")
  i <- grep("^local\\(\\{", src)[1]; j <- grep("^\\}\\)", src)[1]; eval(parse(text = src[-(i:j)]), envir = e)
  cc <- case_of(cs); rg <- cc$rec %||% cs; sd <- as.numeric(cc$seed %||% e$RAIN_SPECS[[rg]]$seed)
  sc <- sprintf("%s, seed %s", rg, sd); e$RAIN_SPECS[[sc]] <- modifyList(e$RAIN_SPECS[[rg]], list(seed = sd)); e$rain_record(sc) }
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a
