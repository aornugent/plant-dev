# Which case and constraint fails, per draw, for the named candidates.
suppressMessages(source("/home/user/plant-dev/harness/schedule/surrogate.R"))
for (f in commandArgs(TRUE)) { env <- new.env(); sys.source(file.path(Sys.getenv("D"), "search", f), env)
  cat("==", f, "\n")
  for (d in 1:20) { STRESS <<- d; r <- evaluate(function(ctx) env$algorithm(ctx)); if (r$feasible) next
    t <- r$table; c5 <- vapply(r$detail, function(x) if (is.null(x$C5)) TRUE else x$C5, TRUE)
    bad <- which(!(t$C1 & t$C2 & t$C3 & c5))
    for (i in bad) { x <- r$detail[[i]]; big <- pmax(abs(x$err), x$est) > 1/3
      cat(sprintf(" d%02d %-12s C1=%d C2=%d C3=%d C5=%d worst=%.2f path=%s\n", d, t$case[i], t$C1[i], t$C2[i], t$C3[i], c5[i], t$worst[i], t$path[i]))
      if (!t$C3[i] || !t$C1[i]) { k <- names(x$err)[big]; print(round(rbind(err = x$err[k], est = x$est[k], sest = if (!is.null(x$sest)) x$sest[k]), 2)) } } }
}
