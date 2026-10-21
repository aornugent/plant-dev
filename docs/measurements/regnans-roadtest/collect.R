# Collect each climate's roadtest rds into one table.
# Run as: Rscript collect.R <dir> <out.csv>
args <- commandArgs(TRUE)
files <- list.files(args[[1]], "^roadtest-.*\\.rds$", full.names = TRUE)
num <- function(x) if (is.null(x) || length(x) == 0) NA_real_ else as.numeric(x[[1]])
chr <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else as.character(x[[1]])
row <- function(f) {
  o <- readRDS(f)
  r <- o$refine
  land <- o$landscape
  best <- if (is.null(land)) NA else land$factor[which.max(land$log_R)]
  t <- function(n) num(o$times[[n]])
  data.frame(
    climate = o$climate, pilot_J = num(o$pilot_J), b0 = num(o$b0),
    refine_status = chr(r$status), refine_level = num(r$level), nodes = length(r$nodes),
    spell_edges = num(r$spells), worst_bound = num(r$worst_bound), worst_quantity = chr(r$worst),
    rebuilt = isTRUE(o$rebuilt), b_star = num(o$equilibrium$b), newton_runs = num(o$equilibrium$runs),
    dlnJ_dlnb = num(o$equilibrium$slope), log_R_self = num(o$selection[["log_R"]]),
    gradient_sweep = num(o$selection[["gradient"]]),
    gradient_cd_h1e4 = num(o$central_difference[["h1e-04"]]),
    gradient_cd_h1e3 = num(o$central_difference[["h0.001"]]),
    landscape_best_factor = best,
    landscape_log_R = if (is.null(land)) NA else paste(sprintf("%.4f", land$log_R), collapse = " "),
    hill_lma1 = num(o$hill$lma1), hill_b1 = num(o$hill$b1), hill_runs = num(o$hill$runs),
    hill_log_R_old = num(o$hill$log_R_old),
    s_pilot = t("pilot"), s_refine = t("refine"), s_newton = t("newton"),
    s_refine_again = t("refine_again"), s_newton_again = t("newton_again"),
    s_sweep = t("sweep"), s_landscape = t("landscape"), s_central_difference = t("central_difference"),
    s_hill_equilibrium = t("hill_equilibrium"), s_back_invasion = t("back_invasion"), s_total = t("total"),
    failures = if (length(o$failures)) paste(names(o$failures), unlist(o$failures), sep = ": ", collapse = " | ") else "",
    stringsAsFactors = FALSE)
}
tab <- do.call(rbind, lapply(files, row))
write.csv(tab, args[[2]], row.names = FALSE)
print(tab[, c("climate", "refine_status", "nodes", "b_star", "newton_runs", "gradient_sweep",
              "gradient_cd_h1e4", "landscape_best_factor", "s_total")])
