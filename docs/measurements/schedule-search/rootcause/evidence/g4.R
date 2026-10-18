# g4.R: the node-drop map's ln J estimate against the pinned drop's (R0) per region, and
# both against the measured region error (ladders), on the single round's three cases and
# the dwr round's coarse run x. Each is e = move/3 in eps of ln J.
SC <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
meas <- readRDS(file.path(SC, "dwr", "score_ind_dry_dry-flat_long-wet_dry-p50_episodic_episodic-lma_long-drought_ld-102_ld-105_wet-adG2.rds"))
rows <- list()
for (cs in c("dry", "dry-flat", "episodic-lma")) {
  x <- readRDS(file.path(SC, "single", sprintf("score_%s.rds", cs)))$est
  M <- meas[[cs]]$M
  for (g in names(x)) { o <- x[[g]]; if (is.null(o$map) || is.null(o$R0)) next
    m <- if (!is.null(M) && g %in% names(M)) unname(M[[g]]["lnJ"]) else NA
    rows[[length(rows) + 1]] <- data.frame(case = cs, run = "c", region = g, map = unname(o$map["lnJ"]), drop = unname(o$R0["lnJ"]),
      gap = unname(o$map["lnJ"] - o$R0["lnJ"]), measured = m, drop_minus_meas = unname(o$R0["lnJ"]) - m,
      own = unname(o$map["own"]), field = unname(o$map["field"])) } }
# dwr coarse run x: map D and pinned D (in eps of ln J, before /3)
mx <- readRDS(file.path(SC, "dwr", "score_x_dry.rds"))$tab
u <- 0.025; base <- readRDS(file.path(SC, "dwr", "runs", "map_x_dry.rds"))$stand$J
for (g in c("I", "F")) { p <- readRDS(file.path(SC, "dwr", "runs", sprintf("plain_x_%s_dry.rds", g)))$stand$J
  rows[[length(rows) + 1]] <- data.frame(case = "dry", run = "x", region = g, map = mx$e[mx$region == g], drop = log(p / base) / u / 3,
    gap = mx$e[mx$region == g] - log(p / base) / u / 3, measured = NA, drop_minus_meas = NA, own = mx$own[mx$region == g] / 3, field = mx$field[mx$region == g] / 3) }
tab <- do.call(rbind, rows); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(SC, "evidence", "g4.rds"))
