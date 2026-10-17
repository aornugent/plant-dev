# cal_int.R: the interval check's threshold from U's ladders (rule in notes.md, L). Per case
# the widest open interval before b = 20 of each rung (as b_loop.R computes it) and the x-c
# pair's last-run estimate (Q_x - Q_c)/(1.6^2 - 1) scored by C1-C5 with its read.
U <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u"
D <- readRDS(file.path(U, "lad_U.rds")); L <- D$L; EPS <- D$EPS
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }
mi <- function(l, k) { S <- l$runs[[k]]$S; m <- (head(S, -1) + S[-1]) / 2; h <- diff(S) * 365; max(h[m < 20 & l$pilot$shut(m) < 0.5]) }
T <- do.call(rbind, lapply(names(L), function(cs) { l <- L[[cs]]; e <- lapply(l$runs, function(r) (r$q - l$ref) / EPS)
  pr <- function(a, b, ra, rb) { est <- (e[[a]] - e[[b]]) / ((ra / rb)^2 - 1); cr <- crit(e[[b]], est); j <- abs(e[[b]]) > 0.2; c(pass = all(cr), read = median((est / e[[b]])[j])) }
  xc <- pr("x", "c", 1.6, 1); cf <- pr("c", "f", 1, 1 / 1.6)
  data.frame(case = cs, mi_x = mi(l, "x"), mi_c = mi(l, "c"), mi_f = mi(l, "f"), xc_pass = as.logical(xc[["pass"]]), xc_read = xc[["read"]], cf_pass = as.logical(cf[["pass"]]), cf_read = cf[["read"]]) }))
T$ok <- T$xc_pass & T$xc_read >= 0.7 & T$xc_read <= 1.4
INT <- if (any(!T$ok)) min(T$mi_x[!T$ok]) else max(T$mi_x) + 1
print(T, digits = 3, row.names = FALSE); cat(sprintf("INT = %.1f d (%s)\n", INT, if (any(!T$ok)) "narrowest failing coarse run" else "widest U16 interval + 1 d")); writeLines(sprintf("%.1f", INT), file.path(U, "INT.txt"))
