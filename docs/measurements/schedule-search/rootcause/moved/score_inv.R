# score_inv.R: invaders at lma x0.5, x2 and theta' = theta on dry's committed grid, each
# against its u215/u429 reference (square-law extrapolation) in invader eps, with ln J'
# also in absolute terms; growth against the theta' = theta invader and against the
# resident; the resident's check estimate as a reading of each; the S_el ratio.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
MV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved"
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
NR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/node_rule/ladder/runs"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; M <- D$M_unit[Q]; EL <- setdiff(Q, "lnJ")
et <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
EPSI <- vapply(Q, function(n) if (n == "lnJ") 0.025 else { e <- et$eps[et$role == "invader" & et$trait == n & et$unit != "curvature in lma"]; max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }, 0)
qi <- function(r) { if (is.null(r$elasticity)) return(NULL); e <- unname(r$elasticity); names(e) <- sub("^1\\.", "", names(r$elasticity)); c(lnJ = log(r$J), e)[Q] }
W <- function(e) max(abs(e)); rms <- function(e) sqrt(mean(e^2)); Sel <- function(q, eps) sqrt(mean((q[EL] / eps[EL])^2))
read <- function(est, err) { j <- abs(err) > 0.2; if (any(j)) median(est[j] / err[j]) else NA }
c3n <- function(err, est) { big <- pmax(abs(err), abs(est)) > 1 / 3
  ok <- abs(est) >= abs(err) / 2 & abs(est) <= 2 * abs(err) & sign(est) == sign(err)
  sprintf("%d/%d%s", sum(ok & big), sum(big), if (sum(!ok & big) <= max(1, floor(0.2 * sum(big)))) " pass" else " FAIL") }

g <- readRDS(file.path(MV, "runs", "inv_dry_grid.rds")); c0 <- readRDS(file.path(AR, "val_insk_c_dry.rds"))
r1 <- readRDS(file.path(MV, "runs", "inv_dry_u215.rds")); r2 <- readRDS(file.path(MV, "runs", "inv_dry_u429.rds"))
o1 <- readRDS(file.path(NR, "u215_dry.rds")); o2 <- readRDS(file.path(NR, "u429_dry.rds"))
cat(sprintf("guard grid: stand J %.15g vs val_insk_c_dry %.15g identical %s; theta'=theta J' %.15g identical to stand %s; sweep value = J' %s\n",
  g$stand$J, c0$stand$J, identical(g$stand$J, c0$stand$J), g$invaders[["lma=0"]]$J, identical(g$invaders[["lma=0"]]$J, g$stand$J),
  paste(vapply(g$invaders, function(v) sprintf("%.3g", if (is.null(v$value)) NA else unname(v$value) / v$J - 1), ""), collapse = " ")))
for (z in list(list(r1, o1, 215), list(r2, o2, 429))) { a <- z[[1]]; b <- z[[2]]
  d <- max(abs((qi(a$invader) - qi(b$invader)) / EPSI))
  cat(sprintf("guard u%d: stand J %.12g vs saved %.12g identical %s | theta'=theta invader max |diff| %.3g eps (identical %s) | failures %d\n",
    z[[3]], a$stand$J, b$stand$J, identical(a$stand$J, b$stand$J), d, identical(a$invader$elasticity, b$invader$elasticity), length(a$failures))) }
cat("phases (cpu s):", paste(sprintf("%s %.0f", names(r2$phases), vapply(r2$phases, `[[`, 0, "cpu_secs")), collapse = "; "), "\n")
cat("grid cpu: stand", round(g$stand$cpu), "| walks", paste(sprintf("%s %.0f+%.0f", names(g$invaders), vapply(g$invaders, `[[`, 0, "cpu"), vapply(g$invaders, function(v) if (is.null(v$sweep_cpu)) NA else v$sweep_cpu, 0)), collapse = "; "), "\n")

# References: theta' = theta from the saved dry ladder; the moved invaders from the new runs.
ref <- function(a, b) { x <- qi(a); y <- qi(b); if (is.null(x) || is.null(y)) return(NULL); r <- extrap(x, y); attr(r, "own") <- (y - x) / 3; r }
REFS <- list(`lma=0` = ref(o1$invader, o2$invader), `lma=-0.5` = ref(r1$invaders[["rel:lma=-0.5"]], r2$invaders[["rel:lma=-0.5"]]),
  `lma=1` = ref(r1$invaders[["rel:lma=1"]], r2$invaders[["rel:lma=1"]]))
# The resident on its own grid, and its check estimate converted to each invader's eps.
R <- L$dry$runs; e_res <- (R$c$q - L$dry$ref) / EPS; est_abs <- (R$c$q - R$f$q) / (1 - R$f$proxy / R$c$proxy)
out <- list(); E <- list()
for (k in names(REFS)) { rf <- REFS[[k]]; q <- qi(g$invaders[[k]])
  if (is.null(rf) || is.null(q)) { cat(k, ": missing (walk or gradient failed)\n"); next }
  e <- (q - rf) / EPSI; E[[k]] <- e; own <- attr(rf, "own") / EPSI
  est <- est_abs / EPSI
  cat(sprintf("\n== invader %s: J' %.6g (ref %.6g) | ln J' error %+.4f absolute (%+.2f eps) | W %.2f (%s) rms %.3f along M %+.2f | ref's own |u429-u215|/3: W %.2f, ln J' %.4f\n",
    k, exp(q[["lnJ"]]), exp(rf[["lnJ"]]), q[["lnJ"]] - rf[["lnJ"]], e[["lnJ"]], W(e), Q[which.max(abs(e))], rms(e), sum(e * M), W(own), abs(attr(rf, "own")[["lnJ"]])))
  cat(sprintf("   resident check (in invader eps) -> e: read %.2f corr %.2f C3 %s W read %.2f | S_el (invader eps) %.2f\n", read(est, e), cor(est, e), c3n(e, est), W(est) / W(e), Sel(q, EPSI)))
  oo <- order(-abs(e))[1:6]
  print(data.frame(q = Q[oo], err = round(e[oo], 2), elasticity = signif(q[oo], 3), ref = signif(rf[oo], 3), eps = signif(EPSI[oo], 2), est = round(est[oo], 2), ref_own = round(own[oo], 2)), row.names = FALSE)
  out[[k]] <- data.frame(inv = k, J = exp(q[["lnJ"]]), dlnJ = q[["lnJ"]] - rf[["lnJ"]], W = W(e), rms = rms(e), Sel = Sel(q, EPSI), ref_own_W = W(own)) }
O <- do.call(rbind, out)
if (!is.null(O) && "lma=0" %in% O$inv) { b <- O[O$inv == "lma=0", ]
  O$growth_inv <- O$W / b$W; O$reserve_inv <- pmax(0, 1 - 1 / O$growth_inv); O$growth_rms <- O$rms / b$rms; O$Sel_ratio <- O$Sel / b$Sel
  O$growth_res <- O$W / W(e_res); O$reserve_res <- pmax(0, 1 - 1 / O$growth_res) }
cat(sprintf("\nresident on dry's grid: W %.2f rms %.3f (resident eps)\n", W(e_res), rms(e_res)))
print(O, digits = 3, row.names = FALSE)
if (length(E) > 1) { cs <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2)); for (k in setdiff(names(E), "lma=0")) if (!is.null(E[["lma=0"]])) cat(sprintf("cos(e %s, e theta'=theta) %.2f\n", k, cs(E[[k]], E[["lma=0"]]))) }
saveRDS(list(O = O, E = E), file.path(MV, "score_inv.rds"))
