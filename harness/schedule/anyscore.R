# Scores a schedule-building algorithm that may request any schedule, in seconds.
# A run's errors come from anysched.R: ln J from the case's J maps (density x h^3 per
# interval), each elasticity from per-band factors fitted on the case's real runs. Cost
# comes from rows fitted on node count and summed remaining life. Agents do not edit it.
source("/home/user/plant-dev/harness/schedule/anysched.R")
H <- 39.6; STRESS <- 0; RUN_SD <- 0.04
CASEDATA <- new.env()
prepare <- function(case) {
  if (!is.null(CASEDATA[[case]])) return(CASEDATA[[case]])
  cd <- case_data(case); rs <- cd$runs; Qs <- Reduce(intersect, lapply(rs, function(r) names(r$err)))
  kap <- lapply(setNames(Qs, Qs), function(Q) fit_kappa(rs, Q))
  fit <- rs[!grepl("_f8_", sapply(rs, `[[`, "name"))]
  sd <- vapply(Qs, function(Q) sqrt(mean(vapply(seq_along(fit), function(i)
    ((if (Q == "lnJ") fit[[i]]$X[["lnJ_signed"]] else predict_err(fit[[i]], fit_kappa(fit[-i], Q))) - fit[[i]]$err[Q])^2, 0))), 0)
  d <- data.frame(n = sapply(rs, function(r) length(r$S)), life = sapply(rs, function(r) sum(H - r$S)), rows = sapply(rs, `[[`, "rows"))
  pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(case_of(case)$pilot, ".rds")))$stand
  CASEDATA[[case]] <- c(cd, list(Qs = Qs, kap = kap, sd = sd, rowsfit = lm(rows ~ 0 + n + life, d), ref = reference(case), edges = pe$edges,
    pilot = list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, J = px$J, creation = as.data.frame(px$creation),
                 nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")]), soil = px$soil)))
  CASEDATA[[case]] }
# The scorer's range: every pilot edge is a node; open intervals at most b1/12 in the
# founders' window, 100 d before b = 20 and 280 d after.
check_range <- function(cd, S) {
  if (S[1] != 0 || any(diff(S) <= 0) || tail(S, 1) >= H) stop("a schedule is increasing, starts at 0 and ends before ", H)
  miss <- cd$edges[vapply(cd$edges, function(e) min(abs(S - e)) > 1e-6, TRUE)]
  if (length(miss)) stop(sprintf("schedule lacks %d pilot edges (first %.4f)", length(miss), miss[1]))
  lo <- S[-length(S)]; hi <- c(S[-1]); w <- hi - lo; open <- cd$shut((lo + hi) / 2) < 0.5
  cap <- ifelse(hi <= cd$b1 + 1e-9, cd$b1 / 12, ifelse(lo < 20, 100 / 365, 280 / 365))
  if (any(open & w > cap + 1e-9)) stop(sprintf("interval [%.3f, %.3f] is wider than the scorer's range", lo[open & w > cap][1], hi[open & w > cap][1]))
}
# NOISE = "2" (the default): the scorer's miss is drawn once per case and draw, shared by
# every run, since it is a property of the case rather than of a run; jitter is drawn
# per run, but a run nested in an earlier one (either contains the other's nodes) takes
# the earlier run's jitter, as nested real runs share theirs. NOISE = "1": both per run.
NOISE <- Sys.getenv("NOISE", "2")
hash_S <- function(S) sum(round(S * 1e6) %% 9973 * seq_along(S)) %% 1e6
nested <- function(A, B) { a <- round(A, 8); b <- round(B, 8); all(a %in% b) || all(b %in% a) }
sim <- function(cd, S, case, reg = NULL) {
  X <- features(case, S, cd$dens, cd$shut, cd$b1)
  err <- vapply(cd$Qs, function(Q) if (Q == "lnJ") X[["lnJ_signed"]] else { x <- X[-1]; x[is.na(x)] <- 0; sum(cd$kap[[Q]] * x) }, 0)
  if (STRESS > 0 && NOISE == "1") { set.seed(STRESS * 1e6 + sum(round(S * 1e4)) %% 1e6); err <- err + rnorm(length(err)) * sqrt(cd$sd^2 + RUN_SD^2) }
  if (STRESS > 0 && NOISE != "1") {
    set.seed(STRESS * 1e6 + sum(utf8ToInt(case))); miss <- rnorm(length(err)) * cd$sd
    z <- NULL; if (!is.null(reg)) for (r in reg$runs) if (nested(r$S, S)) { z <- r$z; break }
    if (is.null(z)) { set.seed(STRESS * 1e6 + 500009 + hash_S(S)); z <- rnorm(length(err)) * RUN_SD
      if (!is.null(reg)) reg$runs[[length(reg$runs) + 1]] <- list(S = S, z = z) }
    err <- err + miss + z }
  list(q = cd$ref[cd$Qs] + err * eps_vec(cd$Qs), err = err) }
evaluate_any_case <- function(alg, case) {
  cd <- prepare(case); spent <- 0; seen <- new.env(); path <- c(); reg <- new.env(); reg$runs <- list()
  rows_of <- function(S) max(1, predict(cd$rowsfit, data.frame(n = length(S), life = sum(H - S))))
  ctx <- list(pilot = cd$pilot, horizon = H, eps = function(k) eps_vec(k),
    run = function(S, gradient = TRUE, drop = NULL) {
      S <- sort(round(S, 10)); check_range(cd, S); key <- paste(digest_S(S), gradient, paste(drop, collapse = ","))
      if (is.null(seen[[key]])) { rows <- rows_of(S); spent <<- spent + run_cost(rows, gradient) * (if (length(drop)) 1 + 0.054 else 1)
        path <<- c(path, sprintf("%d%s%s", length(S), if (gradient) "" else "f", if (length(drop)) "m" else "")); seen[[key]] <- TRUE }
      r <- sim(cd, S, case, reg); q <- if (gradient) r$q else r$q["lnJ"]
      map <- NULL
      if (length(drop)) { if (!gradient) stop("a map needs the gradient run")
        j <- drop; if (any(j <= 1 | j >= length(S))) stop("a dropped node has a neighbour on each side")
        h1 <- S[j] - S[j - 1]; h2 <- S[j + 1] - S[j]
        m <- cd$dens((S[j - 1] + S[j + 1]) / 2) * ((h1 + h2)^3 - h1^3 - h2^3)
        m[cd$shut((S[j - 1] + S[j + 1]) / 2) > 0.5] <- 0
        if (STRESS > 0) { set.seed(STRESS * 1e6 + 7 + hash_S(S)); m <- m * (1 + 0.08 * rnorm(length(m))) }
        map <- data.frame(birth = S[j], move = m) }
      list(q = q, rows = rows_of(S), map = map) })
  out <- alg(ctx)
  uq <- lapply(out$use, function(S) sim(cd, sort(round(S, 10)), case, reg)$q)
  k <- cd$Qs; if (length(setdiff(k, intersect(names(out$answer), names(out$estimate))))) stop("answer or estimate leaves out a quantity")
  from_use <- if (length(uq) == 1) isTRUE(all.equal(unname(out$answer[k]), unname(uq[[1]][k]), tolerance = 1e-10)) else {
    dd <- uq[[2]][k] - uq[[1]][k]; i <- which.max(abs(dd)); c0 <- (out$answer[k][i] - uq[[2]][k][i]) / dd[i]
    isTRUE(all.equal(unname(out$answer[k]), unname(uq[[2]][k] + c0 * dd), tolerance = 1e-8)) }
  if (!from_use) stop("answer does not come from the runs in `use`")
  t_use <- sum(vapply(out$use, function(S) run_cost(rows_of(sort(round(S, 10))), TRUE), 0))
  e <- eps_vec(k); err <- (out$answer[k] - cd$ref[k]) / e; sest <- out$estimate[k] / e; est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  list(case = case, T_find = spent, T_use = t_use, T = spent + 2 * t_use, worst = max(abs(err)),
    C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    # Honest: within x2 with the error's sign on 80% of the quantities over eps/3; with
    # under five such quantities, one may miss.
    C3 = if (any(big)) { ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
      if (NOISE == "1") mean(ok3) >= 0.8 else sum(!ok3) <= max(1, floor(0.2 * sum(big))) } else TRUE,
    C5 = all(est <= 1), path = paste(path, collapse = " > "), err = err, est = sest, n_use = sapply(out$use, length)) }
digest_S <- function(S) sprintf("%d:%.10f:%.10f", length(S), sum(S), sum(S^2))
evaluate_any <- function(alg, cases = names(CASES)) {
  res <- lapply(cases, function(cs) tryCatch(evaluate_any_case(alg, cs), error = function(e) list(case = cs, error = conditionMessage(e))))
  tab <- do.call(rbind, lapply(res, function(r) if (!is.null(r$error)) data.frame(case = r$case, T = NA, T_find = NA, T_use = NA, worst = NA, C1 = FALSE, C2 = FALSE, C3 = FALSE, C5 = FALSE, path = r$error) else
    data.frame(case = r$case, T = r$T, T_find = r$T_find, T_use = r$T_use, worst = r$worst, C1 = r$C1, C2 = r$C2, C3 = r$C3, C5 = r$C5, path = r$path)))
  list(table = tab, T = sum(tab$T), feasible = all(tab$C1 & tab$C2 & tab$C3 & tab$C5), detail = res) }
