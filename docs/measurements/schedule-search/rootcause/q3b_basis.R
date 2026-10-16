# q3b_basis.R: two physical directions from moves that change one region: the founders'
# window (lattice f 8 -> 16 at l 70) and the spells (lattice l 140 -> 70 at f 16, edges as
# nodes). Are they the same across cases, and how much of every run's error do they span?
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
v <- function(nm) qn(nm)[Q] / EPS; u <- function(x) x / sqrt(sum(x^2))
cs5 <- c("dry", "episodic", "episodic-lma", "long-drought", "long-wet")
Fm <- sapply(cs5, function(cs) u(v(sprintf("lat_%s_f16_l70", cs)) - v(sprintf("lat_%s_f8_l70", cs))))
Lm <- sapply(cs5, function(cs) u(v(sprintf("lat_%s_f16_l70", cs)) - v(sprintf("lat_%s_f16_l140", cs))))
cat("cosines of founders moves across cases:\n"); print(round(crossprod(Fm), 2))
cat("cosines of spell (late-axis) moves across cases:\n"); print(round(crossprod(Lm), 2))
cat("cos(founders move, spell move) same case:", round(diag(crossprod(Fm, Lm)), 2), "\n")
cat("cos(spell move, M):", round(colSums(Lm * M_unit), 2), " cos(founders move, M):", round(colSums(Fm * M_unit), 2), "\n")
FT <- readRDS(file.path(OUT, "feat.rds")); meta <- FT$meta; E <- FT$E
i <- meta$build == "L19" & complete.cases(E) & meta$tol == 1e-4 & meta$rms <= 0.5
# per held-out case: span of {its own case-independent basis}: mean founders dir (others), M
for (cs in ALL) { j <- i & meta$case == cs; if (!any(j)) next
  oth <- setdiff(cs5, cs); B <- qr.Q(qr(cbind(u(rowMeans(Fm[, oth, drop = FALSE])), M_unit)))
  X <- E[j, , drop = FALSE]; P <- X %*% B %*% t(B)
  cat(sprintf("%-13s n %3d share of squared error in span(founders dir, M): %.2f\n", cs, sum(j), sum(P^2) / sum(X^2))) }
saveRDS(list(Fdir = u(rowMeans(Fm)), Ldir = u(rowMeans(Lm))), file.path(OUT, "q3b_basis.rds"))
