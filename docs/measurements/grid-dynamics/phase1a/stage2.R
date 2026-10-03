# Stage 2's tests (prereg.txt) for each nudge triple (x0.95, x1, x1.05 of the
# working tolerance): R2, the largest |move| of each main quantity against x1 in units
# of eps/3; R1, |Q(x1) - Q_ref| in units of eps. Plant-replayed triples carry both roles'
# reverse-mode elasticities; frozen triples the resident's central differences on the
# driver; the baseline's frozen triple carries ln J and the frozen (total) lma.
#   Rscript stage2.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
W <- "/home/user/plant-dev/.claude/worktrees/agent-a49b34f804b88b2d4"
JSTAR <- 12.6687135
u <- 1e-5
eps <- read.csv(file.path(W, "docs/measurements/eps.csv"))
eps_of <- function(role, q) {
  e <- eps$eps[eps$role == role & eps$trait == (if (q == "lnJ") "ln J" else q)]
  if (length(e)) e[1] else NA
}
RES <- c("lnJ", "lma", "a_dG2", "a_dG1", "d_I", "storage_relaxation_offset", "TF24_cost_scale")
INV <- c("lnJ", "lma", "a_dG2")
FROZEN <- c("lma", "a_dG1", "a_dG2", "d_I")
nudges <- c(lo = 0.95, mid = 1, hi = 1.05)
tag <- function(tol) vapply(tol, function(x) sub("e([-+])0*", "e\\1", format(x, scientific = TRUE, digits = 3)), "")

# One plant replay's main quantities, both roles; NULL if absent or unfinished.
plant_q <- function(f) {
  if (!file.exists(f)) return(NULL)
  r <- readRDS(f)
  if (is.null(r$invader$elasticity) || is.null(r$stand$elasticity)) return(NULL)
  es <- r$stand$elasticity; names(es) <- sub("^1\\.", "", names(es))
  ei <- r$invader$elasticity; names(ei) <- sub("^1\\.", "", names(ei))
  rbind(data.frame(role = "resident", q = RES, value = c(log(r$stand$J), es[RES[-1]])),
        data.frame(role = "invader", q = INV, value = c(log(r$invader$J), ei[INV[-1]])))
}
J_of <- function(f) if (file.exists(f)) readRDS(f)$J else NA
# One driver program's frozen quantities: ln J from the run, E by central differences.
U <- c(lma = 1e-4, a_dG1 = 1e-4, a_dG2 = 1e-4, d_I = 1e-3)  # amendment 2
frozen_q <- function(run, stem) {
  E <- vapply(FROZEN, function(th) {
    log(J_of(sprintf("%s_%s_+.rds", stem, th)) / J_of(sprintf("%s_%s_-.rds", stem, th))) /
      (log1p(U[[th]]) - log1p(-U[[th]]))
  }, 0)
  data.frame(role = "resident", q = c("lnJ", FROZEN), value = c(log(J_of(run)), E))
}

ref <- readRDS(file.path(W, "docs/measurements/nudges/ld_1e-5.rds"))
ref_q <- plant_q(file.path(W, "docs/measurements/nudges/ld_1e-5.rds"))
ref_q$value[ref_q$q == "lnJ"] <- log(JSTAR)

# Each triple: three data frames of (role, q, value) at x0.95, x1, x1.05.
report <- function(name, tri, frozen_lma_ref = NA) {
  if (any(vapply(tri, is.null, TRUE))) { cat(sprintf("%s: incomplete\n", name)); return(invisible()) }
  m <- Reduce(function(a, b) merge(a, b, by = c("role", "q")), Map(function(d, k) {
    names(d)[3] <- k; d }, tri, names(tri)))
  m$eps <- mapply(eps_of, m$role, m$q)
  m$move <- pmax(abs(m$lo - m$mid), abs(m$hi - m$mid))
  m$R2 <- m$move / (m$eps / 3)
  rq <- merge(m[, c("role", "q")], ref_q, by = c("role", "q"), all.x = TRUE)
  m$ref <- rq$value[match(paste(m$role, m$q), paste(rq$role, rq$q))]
  if (!is.na(frozen_lma_ref)) m$ref[m$q == "lma" & m$role == "resident"] <- frozen_lma_ref
  m$R1 <- abs(m$mid - m$ref) / m$eps
  m <- m[order(m$role != "resident", match(m$q, RES)), ]
  cat(sprintf("\n== %s\n", name))
  print(data.frame(role = m$role, q = m$q, x0.95 = signif(m$lo, 7), x1 = signif(m$mid, 7),
                   x1.05 = signif(m$hi, 7), move = signif(m$move, 3), `move/(eps/3)` = round(m$R2, 3),
                   ref = signif(m$ref, 7), `|x1-ref|/eps` = round(m$R1, 3), check.names = FALSE),
        row.names = FALSE)
  cat(sprintf("   R2 (all < 1): %s, worst %.3f (%s %s); R1 (all < 1): %s, worst %.3f (%s %s)\n",
              all(m$R2 < 1, na.rm = TRUE), max(m$R2, na.rm = TRUE), m$role[which.max(m$R2)], m$q[which.max(m$R2)],
              all(m$R1 < 1, na.rm = TRUE), max(m$R1, na.rm = TRUE), m$role[which.max(m$R1)], m$q[which.max(m$R1)]))
  invisible(m)
}

# The baseline's frozen triple: ln J and the frozen lma (DEV/pi), 3e-5 replays logged.
pi_runs <- file.path(D, "pi/runs")
base_frozen <- lapply(c(lo = "2.85e-5", mid = "3e-5", hi = "3.15e-5"), function(k) {
  Jp <- J_of(file.path(pi_runs, sprintf("frozen_base_%s_+.rds", k)))
  Jm <- J_of(file.path(pi_runs, sprintf("frozen_base_%s_-.rds", k)))
  if (k == "3e-5") { Jp <- 12.667923702; Jm <- 12.669185516 }
  data.frame(role = "resident", q = c("lnJ", "lma"),
             value = c(log(J_of(file.path(pi_runs, sprintf("base_%s.rds", k)))), log(Jp / Jm) / (log1p(u) - log1p(-u))))
})
base_lma <- mean(vapply(base_frozen, function(d) d$value[d$q == "lma"], 0))
report("baseline CK, frozen (DEV/pi)", base_frozen, base_lma)

# The assessment's plant nudge triples on the same fixture (plant's own control, tied):
# the baseline at the 1e-5 and 1e-4 working tolerances.
NG <- file.path(W, "docs/measurements/nudges")
for (w in c("1e-5", "1e-4")) {
  k <- c(lo = if (w == "1e-5") "9.5e-6" else "9.5e-5", mid = w, hi = if (w == "1e-5") "1.05e-5" else "1.05e-4")
  report(sprintf("baseline CK around %s, plant's own control (docs/measurements/nudges)", w),
         lapply(k, function(x) plant_q(file.path(NG, sprintf("ld_%s.rds", x)))))
}

# Plant replays of the baseline programs (3e-5 from the window test), if run.
bp <- list(lo = plant_q(file.path(P, "plant/base_2.85e-5.rds")),
           mid = plant_q(file.path(D, "window/full/ld_pin_base.rds")),
           hi = plant_q(file.path(P, "plant/base_3.15e-5.rds")))
report("baseline CK, plant replays", bp)

# The variants' triples, from what exists.
for (v in c("ck10", "ck100", "ck100a", "ck10a")) for (w in c(3e-5, 1e-5, 1e-4)) {
  f <- file.path(P, "plant", sprintf("%s_%s.rds", v, tag(w * nudges)))
  if (!file.exists(f[2])) next
  report(sprintf("%s around %s, plant replays", v, tag(w)), setNames(lapply(f, plant_q), names(nudges)))
}
for (v in c("arkfree", "ark100", "ark100a")) for (w in c(3e-5, 1e-5, 1e-4)) {
  runs <- file.path(P, "runs", sprintf("%s_%s.rds", v, tag(w * nudges)))
  stems <- file.path(P, "frozen", sprintf("%s_%s", v, tag(w * nudges)))
  if (!file.exists(sprintf("%s_lma_+.rds", stems[2]))) next
  report(sprintf("%s around %s, frozen differences (partial, THETA_AFTER=1)", v, tag(w)),
         setNames(Map(frozen_q, runs, stems), names(nudges)))
}
