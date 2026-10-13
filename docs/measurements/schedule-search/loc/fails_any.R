# fails_any.R FILE [N]: per draw, the case and constraint that fail, with the quantities over eps/3.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env); N <- if (length(a) > 1) as.integer(a[2]) else 10
for (d in seq_len(N)) { STRESS <<- d; r <- evaluate_any(function(ctx) env$algorithm(ctx)); if (r$feasible) next
  for (x in r$detail) { if (!is.null(x$error)) { cat(sprintf(" d%02d %-13s ERROR %s\n", d, x$case, x$error)); next }
    if (x$C1 && x$C2 && x$C3 && x$C5) next
    big <- pmax(abs(x$err), abs(x$est)) > 1/3
    cat(sprintf(" d%02d %-13s C1=%d C2=%d C3=%d C5=%d path %s | %s\n", d, x$case, x$C1, x$C2, x$C3, x$C5, x$path,
      paste(sprintf("%s %+.2f/%+.2f", names(x$err)[big], x$err[big], x$est[big]), collapse = ", "))) } }
