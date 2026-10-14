# errs.R: every saved gradient run that belongs to one of the ten cases, with its error
# per quantity in units of eps against the case's reference. Output G_out/errs.rds:
# list(meta = one row per run, E = matrix runs x quantities (error / eps), ref = refs).
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
OUT <- file.path(DEV, "schedtest/G_out"); I <- readRDS(file.path(OUT, "index.rds"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
AR <- file.path(DEV, "schedtest/adjmap/runs")
cases <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
REF <- lapply(setNames(cases, cases), refq)
m <- I$meta; m <- m[m$grad %in% TRUE & m$dir == "adj", ]
nm <- sub("^adj:", "", m$id)
case_from <- function(n) { for (cs in cases[order(-nchar(cases))]) if (grepl(paste0("_", cs, "($|_)"), n)) return(cs); NA_character_ }
m$case <- vapply(nm, case_from, "")
m <- m[!is.na(m$case) & !grepl("^ref_", nm), ]
nm <- sub("^adj:", "", m$id)
m$kind <- sub("_.*", "", nm)
m$alg <- ifelse(m$kind == "val", sub("^val_([^_]+)_.*", "\\1", nm), NA)
m$cf <- ifelse(m$kind == "val", sub("^val_[^_]+_([cf])_.*", "\\1", nm), NA)
qn <- names(REF$dry)
E <- t(vapply(seq_len(nrow(m)), function(i) { q <- I$q[[m$id[i]]]; r <- REF[[m$case[i]]]
  v <- (q[qn] - r[qn]) / eps_vec(qn); names(v) <- qn; v }, numeric(length(qn))))
rownames(E) <- m$id
saveRDS(list(meta = m, E = E, ref = REF), file.path(OUT, "errs.rds"))
cat(nrow(m), "runs on the ten cases\n"); print(table(m$case, m$kind))
