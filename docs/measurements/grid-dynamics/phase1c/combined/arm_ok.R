# Exit 0 if a run_record.R output finished with no failure and finite gradients
# for both roles; exit 1 otherwise, printing why. The ARK queue stops an arm on 1.
#   Rscript arm_ok.R run.rds
x <- tryCatch(readRDS(commandArgs(TRUE)[1]), error = function(e) NULL)
why <- character()
if (is.null(x) || is.null(x$finished)) why <- c(why, "did not finish")
if (!is.null(x) && length(x$failures)) why <- c(why, paste("failures:", paste(names(x$failures), collapse = ", ")))
for (role in c("stand", "invader")) {
  e <- x[[role]]$elasticity
  if (!is.null(e) && !all(is.finite(e))) why <- c(why, sprintf("%s gradient refused (%d of %d finite)", role,
                                                                sum(is.finite(e)), length(e)))
}
if (length(why)) { cat(paste(why, collapse = "; "), "\n"); quit(status = 1) }
cat("ok\n")
