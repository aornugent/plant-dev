# score_r3.R: round 3 on dry. B's error from its doubled run, (4/3)(Q_B - Q_B2), against B's
# reference error and B's own odd replay; B2's error; Bg's error and its odd replay.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1), n3 = sum(big), miss3 = sum(!ok3)) }
read_of <- function(err, est, lo) { k <- abs(err) > lo; if (any(k)) median(est[k] / err[k]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
rr <- function(nm) { x <- readRDS(file.path(E, "runs", paste0(nm, ".rds"))); stopifnot(!is.null(x$stand$elasticity)); x }
R <- ref_ladder("dry"); b <- rr("B_dry"); bo <- rr("Bo_dry"); q <- function(x) qv(x)
KQ <- c("lnJ", "root_P50", "storage_relaxation_offset", "a_l1", "omega", "TF24_cost_scale", "a")
err_B <- (q(b) - R$ref) / EPS; est_odd <- (q(bo) - q(b)) / 3 / EPS; k <- setdiff(names(err_B), "lnJ")
show <- function(lab, v) cat(sprintf("%-28s %s\n", lab, paste(sprintf("%s %+.2f", KQ, v[KQ]), collapse = "  ")))
show("B: error (reference)", err_B); show("B: odd replay", est_odd)
f2 <- file.path(E, "runs", "B2_dry.rds"); if (file.exists(f2)) { b2 <- rr("B2_dry")
  est2 <- (4 / 3) * (q(b) - q(b2)) / EPS; err2 <- (q(b2) - R$ref) / EPS; show("B: (4/3)(Q_B - Q_B2)", est2); show("B2: error (reference)", err2)
  cat(sprintf("B from B2: cos with B's error %.3f, read %.2f, rms(err - est) %.3f; B2 worst %.2f (%s), rms %.3f; cos(odd replay, B2 estimate) %.3f\n",
    cosv(err_B[k], est2[k]), read_of(err_B, est2, 0.2), sqrt(mean((err_B - est2)^2)), max(abs(err2)), names(err2)[which.max(abs(err2))], sqrt(mean(err2^2)), cosv(est_odd[k], est2[k])))
  cat(sprintf("B2: rows %.0f (x%.2f B), CPU %.0f s\n", b2$stand$rows, b2$stand$rows / b$stand$rows, b2$stand$cpu + b2$sweep_cpu)) }
fg <- file.path(E, "runs", "Bgo_dry.rds"); if (file.exists(fg)) { g <- rr("Bg_dry"); go <- rr("Bgo_dry")
  err_g <- (q(g) - R$ref) / EPS; est_g <- (q(go) - q(g)) / 3 / EPS; show("Bg: error (reference)", err_g); show("Bg: odd replay", est_g)
  cr <- crit(err_g, est_g); cat(sprintf("Bg: worst %.2f (%s), rms %.3f, est max %.2f, cos %.3f, read %.2f, C1 %d C2 %d C3 %d (%d/%d) C5 %d; rows %.0f (x%.2f B), CPU run %.0f replay %.0f, pinned %s\n",
    max(abs(err_g)), names(err_g)[which.max(abs(err_g))], sqrt(mean(err_g^2)), max(abs(est_g)), cosv(err_g[k], est_g[k]), read_of(err_g, est_g, 0.2),
    cr[["C1"]], cr[["C2"]], cr[["C3"]], cr[["miss3"]], cr[["n3"]], cr[["C5"]], g$stand$rows, g$stand$rows / b$stand$rows, g$stand$cpu + g$sweep_cpu, go$stand$cpu + go$sweep_cpu, identical(g$stand$times, go$stand$times))) }
