# Every nudge test of phase 1a under OBJECTIVES.md's eps at 2963fa1 (a tenth of the spread,
# never under 0.01 for an elasticity), with the raw tenth beside it where the floor binds:
# R2, each main quantity's largest move over x0.95 and x1.05 against x1 in units of eps/3;
# R1, |Q(x1) - Q_ref| in units of eps, Q_ref plant's CK run at 1e-5 (ld_1e-5.rds).
#   Rscript nudge_all.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
W <- "/home/user/plant-dev/.claude/worktrees/agent-a49b34f804b88b2d4"
JSTAR <- 12.6687135
eps <- read.csv(file.path(W, "docs/measurements/eps.csv"))
raw_eps <- function(role, q) eps$eps[eps$role == role & eps$trait == (if (q == "lnJ") "ln J" else q)][1]
eps_of <- function(role, q) if (q == "lnJ") raw_eps(role, q) else max(raw_eps(role, q), 0.01)
RES <- c("lnJ", "lma", "a_dG2", "a_dG1", "d_I", "storage_relaxation_offset", "TF24_cost_scale")
INV <- c("lnJ", "lma", "a_dG2")
U <- c(lma = 1e-4, a_dG1 = 1e-4, a_dG2 = 1e-4, d_I = 1e-3)
tag <- function(x) sub("e([-+])0*", "e\\1", format(x, scientific = TRUE, digits = 3))
plant_q <- function(f) {
  if (!file.exists(f)) return(NULL)
  r <- readRDS(f)
  if (is.null(r$invader$elasticity)) return(NULL)
  es <- r$stand$elasticity; names(es) <- sub("^1\\.", "", names(es))
  ei <- r$invader$elasticity; names(ei) <- sub("^1\\.", "", names(ei))
  rbind(data.frame(role = "resident", q = RES, value = c(log(r$stand$J), es[RES[-1]])),
        data.frame(role = "invader", q = INV, value = c(log(r$invader$J), ei[INV[-1]])))
}
J_of <- function(f) if (file.exists(f)) readRDS(f)$J else NA
frozen_q <- function(run, stem) {
  E <- vapply(names(U), function(th) log(J_of(sprintf("%s_%s_+.rds", stem, th)) / J_of(sprintf("%s_%s_-.rds", stem, th))) /
                (log1p(U[[th]]) - log1p(-U[[th]])), 0)
  if (anyNA(E) || is.na(J_of(run))) return(NULL)
  data.frame(role = "resident", q = c("lnJ", names(U)), value = c(log(J_of(run)), E))
}
ref_q <- plant_q(file.path(W, "docs/measurements/nudges/ld_1e-5.rds"))
ref_q$value[ref_q$q == "lnJ"] <- log(JSTAR)
report <- function(name, tri) {
  if (any(vapply(tri, is.null, TRUE))) { cat(sprintf("\n== %s: incomplete\n", name)); return(invisible()) }
  m <- Reduce(function(a, b) merge(a, b, by = c("role", "q")), Map(function(d, k) { names(d)[3] <- k; d }, tri, names(tri)))
  m$eps <- mapply(eps_of, m$role, m$q); m$raw <- mapply(raw_eps, m$role, m$q)
  m$move <- pmax(abs(m$lo - m$mid), abs(m$hi - m$mid))
  m$ref <- ref_q$value[match(paste(m$role, m$q), paste(ref_q$role, ref_q$q))]
  m <- m[order(m$role != "resident", match(m$q, RES)), ]
  cat(sprintf("\n== %s\n", name))
  print(data.frame(role = m$role, q = m$q, x1 = signif(m$mid, 7), move = signif(m$move, 3),
                   `R2 move/(eps/3)` = round(m$move / (m$eps / 3), 3),
                   `R1 |x1-ref|/eps` = round(abs(m$mid - m$ref) / m$eps, 3),
                   `R2 at raw eps` = ifelse(m$raw < m$eps, round(m$move / (m$raw / 3), 3), NA), check.names = FALSE),
        row.names = FALSE)
  r2 <- m$move / (m$eps / 3); r1 <- abs(m$mid - m$ref) / m$eps
  cat(sprintf("   R2: %s, worst %.3f (%s %s); R1: %s, worst %.3f (%s %s)\n",
              if (all(r2 < 1)) "holds" else "FAILS", max(r2), m$role[which.max(r2)], m$q[which.max(r2)],
              if (all(r1 < 1)) "holds" else "FAILS", max(r1), m$role[which.max(r1)], m$q[which.max(r1)]))
}
NG <- file.path(W, "docs/measurements/nudges")
report("CK baseline around 1e-5, plant's own control", lapply(c(lo = "9.5e-6", mid = "1e-5", hi = "1.05e-5"), function(x) plant_q(file.path(NG, sprintf("ld_%s.rds", x)))))
report("CK baseline around 1e-4, plant's own control", lapply(c(lo = "9.5e-5", mid = "1e-4", hi = "1.05e-4"), function(x) plant_q(file.path(NG, sprintf("ld_%s.rds", x)))))
report("ck10 around 3e-5, plant replays (round one)", lapply(c(lo = "2.85e-5", mid = "3e-5", hi = "3.15e-5"), function(x) plant_q(file.path(P, "plant", sprintf("ck10_%s.rds", x)))))
k <- c(lo = "9.5e-6", mid = "1e-5", hi = "1.05e-5")
report("ark100 around 1e-5, frozen (round one)", Map(frozen_q, file.path(P, "runs", sprintf("ark100_%s.rds", k)), file.path(P, "frozen", sprintf("ark100_%s", k))) |> setNames(names(k)))
for (w in c(3e-5, 1e-4)) {
  k <- setNames(vapply(w * c(0.95, 1, 1.05), tag, ""), c("lo", "mid", "hi"))
  report(sprintf("arkc around %s, frozen", tag(w)),
         setNames(Map(frozen_q, file.path(P, "t2/runs", sprintf("arkc_%s.rds", k)), file.path(P, "t2/frozen", sprintf("arkc_%s", k))), names(k)))
}
