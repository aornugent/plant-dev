# err.R: every gradient run's error vector (eps units) against its build's reference.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
use <- TAB$grad & !TAB$bad & !is.na(TAB$case) & TAB$build %in% c("L19", "AG", "S") & !(TAB$build == "AG" & !TAB$case %in% names(REF$AG))
E <- t(vapply(TAB$id[use], function(id) { e <- err_of(id); out <- setNames(rep(NA_real_, length(Q)), Q); out[names(e)] <- e; out }, numeric(length(Q))))
meta <- TAB[use, ]; meta$rms <- sqrt(rowMeans(E^2, na.rm = TRUE)); meta$worst <- apply(abs(E), 1, max, na.rm = TRUE)
meta$lnJ <- E[, "lnJ"]; meta$alongM <- as.vector(E %*% M_unit)
saveRDS(list(E = E, meta = meta), file.path(OUT, "err.rds"))
cat(nrow(E), "runs\n"); print(table(meta$build, meta$tol))
cat("blow-ups (worst > 10 eps):\n"); print(meta[meta$worst > 10, c("id", "case", "build", "tol", "legacy", "worst")], row.names = FALSE)
