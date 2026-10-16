# ff16.R OUT: FF16 at the "offspring arrival" test's parameters (scm_base_parameters,
# lma 0.0825, birth rate 20; and the two-species pair) on the birth-date coordinate, with
# PLANT_SIMPSON as set in the environment (read once per process). Schedules: the default
# (S0), every other node of it (C), and S0 halved (H) and halved again (HH). Per run: J,
# steps, and each node's final height, mortality, offspring and log density; the
# competition at ground level at the end. The two-species pair on its default schedule,
# halved and halved again. Also the default control (height coordinate).
lib <- Sys.getenv("LIB"); .libPaths(c(lib, .libPaths()))
suppressMessages({ library(odelia, lib.loc = lib); library(plant, lib.loc = lib) })
out_file <- commandArgs(TRUE)[1]
p0 <- scm_base_parameters("FF16"); env <- Environment("FF16")
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"), hyperpar = FF16_hyperpar, birth_rate = list(20))
p2 <- add_strategies(p0, trait_matrix(c(0.0825, 0.2625), "lma"), hyperpar = FF16_hyperpar, birth_rate = list(11.99177, 16.51006))
bd <- Control(node_density_in_birth_date = TRUE)
halve <- function(S) sort(c(S, (head(S, -1) + S[-1]) / 2))
S0 <- p1$node_schedule_times[[1]]
sch <- list(S0 = S0, C = S0[c(seq(1, length(S0), by = 2), if (length(S0) %% 2 == 0) length(S0))], H = halve(S0), HH = halve(halve(S0)))
one <- function(...) tryCatch(one_(...), error = function(e) list(J = NA, steps = NA, error = conditionMessage(e)))
one_ <- function(p, ctrl, S = NULL) { if (!is.null(S)) p$node_schedule_times <- rep(list(S), length(p$strategies))
  t0 <- proc.time()[["elapsed"]]; scm <- run_scm(p, env, ctrl)
  sp <- lapply(scm$patch$species, function(s) { st <- matrix(s$ode_state, ncol = s$size, dimnames = list(s$new_node$ode_names))
    list(birth = s$node_times, w = s$establishment_weights, state = st) })
  list(J = scm$offspring_production, steps = length(scm$ode_times), species = sp, lai0 = scm$patch$compute_competition(0), secs = proc.time()[["elapsed"]] - t0) }
res <- list(rule = Sys.getenv("PLANT_SIMPSON"), schedules = sch)
for (k in names(sch)) { res$one[[k]] <- one(p1, bd, sch[[k]]); cat(k, res$one[[k]]$J, "\n") }
res$two <- one(p2, bd)
S2 <- p2$node_schedule_times[[1]]; stopifnot(identical(S2, p2$node_schedule_times[[2]]))
res$two_H <- one(p2, bd, halve(S2)); res$two_HH <- one(p2, bd, halve(halve(S2)))
res$height_one <- one(p1, Control())
res$height_two <- one(p2, Control())
saveRDS(res, out_file)
cat(sprintf("rule %s: one species J %s; two species J %s; height one %.10g\n", res$rule,
  paste(sprintf("%s %.10g (%d nodes, %d steps)", names(sch), sapply(res$one, `[[`, "J"), lengths(sch), sapply(res$one, `[[`, "steps")), collapse = ", "),
  paste(sprintf("%.10g", res$two$J), collapse = " "), res$height_one$J))
for (k in names(res$one)) if (!is.null(res$one[[k]]$error)) cat(k, "failed:", substr(res$one[[k]]$error, 1, 160), "\n")
