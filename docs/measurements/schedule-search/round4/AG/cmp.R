# cmp.R CASE BASE RUN...: each run against BASE (moves) and against the libAG reference
# (errors, eps), with each move projected on two units: M19 = P's lib19 in10 move
# (P_in10 - a09 c on lib19) and MAG = the libAG in10 move (AG_in10 - BASE), when present.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; ref <- ref_ag(cs); B <- ag_run(a[2]); eb <- err_of(B, ref); k <- names(eb)
cat(sprintf("%s reference: own estimate max %.2f eps; window elasticity %.4f\n", cs, attr(ref, "own"), attr(ref, "win")))
mv <- function(x) err_of(x, ref)[k] - eb
unit <- function(n1, n0) tryCatch({ q1 <- quantities(ag_run(n1)); q0 <- quantities(ag_run(n0)); (q1[k] - q0[k]) / eps_vec(k) }, error = function(e) NULL)
M19 <- unit(sprintf("P_in10_%s", cs), sprintf("val_a09_c_%s", cs)); if (is.null(M19)) M19 <- unit(sprintf("P_in10_%s", cs), sprintf("val_a09p_c_%s", cs))
MAG <- unit(sprintf("AG_in10_%s", cs), a[2])
pr <- function(v, M) if (is.null(M)) NA else sum(v * M) / sum(M^2)
cat(sprintf("%-22s n %3d rows %4.0fk cpu %4.0f | error worst %.2f (%s) rms %.3f lnJ %+.3f | err on -M19 %.2f, on -MAG %.2f | win err %+.3f\n", a[2], length(B$node_times), B$stand$rows / 1e3, cpu_of(B), max(abs(eb)), k[which.max(abs(eb))], sqrt(mean(eb^2)), eb["lnJ"], -pr(eb, M19), -pr(eb, MAG), (q_win(B) - attr(ref, "win")) / 0.01))
for (nm in a[-(1:2)]) { x <- ag_run(nm); e <- err_of(x, ref)[k]; m <- e - eb
  cat(sprintf("%-22s n %3d rows %4.0fk cpu %4.0f | move max %.2f (%s) rms %.3f lnJ %+.3f | proj M19 %.2f (corr %.2f) MAG %.2f | corr(move, base err) %.2f | error worst %.2f (%s) rms %.3f | err on -M19 %.2f\n",
    nm, length(x$node_times), x$stand$rows / 1e3, cpu_of(x), max(abs(m)), k[which.max(abs(m))], sqrt(mean(m^2)), m["lnJ"], pr(m, M19), if (is.null(M19)) NA else cor(m, M19), pr(m, MAG), cor(m, eb),
    max(abs(e)), k[which.max(abs(e))], sqrt(mean(e^2)), -pr(e, M19)))
  o <- order(-abs(m))[1:6]; cat("   top moves:", paste(sprintf("%s %+.2f (err %+.2f, base %+.2f)", k[o], m[o], e[o], eb[o]), collapse = "; "), "\n") }
