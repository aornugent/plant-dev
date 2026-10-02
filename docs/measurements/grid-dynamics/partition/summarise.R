# One line per run on disk: J's error against J*, accepted member steps, and the
# costs in transferable units (leaf solves, uptake_at calls, soil-chain rates).
#   Rscript summarise.R [pattern]
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split"
J_STAR <- 12.6687135
pat <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "."
files <- list.files(file.path(S, "out"), pattern = "\\.rds$", full.names = TRUE)
files <- files[grepl(pat, basename(files))]
rows <- lapply(files, function(f) {
  r <- readRDS(f)
  cn <- r$counts
  data.frame(run = sub("\\.rds$", "", basename(f)), method = r$method, tol = r$tol,
             soil_tol = if (is.null(r$soil_tol)) NA else r$soil_tol,
             J = r$J, err = (r$J - J_STAR) / J_STAR, accepted = r$attempts[["accepted"]],
             rejected = r$attempts[["rejected_inaccurate"]] + r$attempts[["rejected_thrown"]],
             leaf_solves = cn$members, sub_leaf = if (is.null(cn$sub_members)) 0 else cn$sub_members,
             uptake_at = if (is.null(cn$uptake_at)) 0 else cn$uptake_at,
             soil_rates = if (is.null(cn$soil_rates)) 0 else cn$soil_rates,
             sub_steps = if (is.null(cn$sub_accepted)) NA else cn$sub_accepted,
             secs = round(r$secs))
})
tab <- do.call(rbind, rows)
tab$total_leaf <- tab$leaf_solves + tab$sub_leaf
options(width = 250)
print(tab[order(tab$method, -tab$tol), ], row.names = FALSE, digits = 4)
