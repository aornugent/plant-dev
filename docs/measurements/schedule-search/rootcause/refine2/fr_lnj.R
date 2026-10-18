# fr_lnj.R: could a forward-only replay (ln J's estimate alone) bound the elasticities? The ratio
# of the largest elasticity estimate and the largest elasticity error to ln J's, per case and run.
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
FR <- readRDS(file.path(SP, "frontier/fr_data.rds"))
r <- do.call(rbind, lapply(names(FR), function(cs) { z <- FR[[cs]]; L <- z$s05$levels
  src <- list(s1 = list(err = z$s1$err, e = z$s1$e), r5 = list(err = z$r5$err, e = z$r5$e),
              s05 = list(err = L[[1]]$err, e = (z$s05$replay$err - L[[1]]$err) / 3))
  do.call(rbind, lapply(names(src), function(s) { a <- src[[s]]; el <- setdiff(names(a$e), "lnJ")
    data.frame(case = cs, source = s, e_lnJ = a$e[["lnJ"]], err_lnJ = a$err[["lnJ"]], e_el_max = max(abs(a$e[el])),
               err_el_max = max(abs(a$err[el])), ratio_err = max(abs(a$err[el])) / abs(a$err[["lnJ"]])) })) }))
print(format(r, digits = 3), row.names = FALSE)
cat(sprintf("largest elasticity error / |ln J error|: %.1f to %.1f\n", min(r$ratio_err), max(r$ratio_err)))
