# score.R: the corrected nudge and errors from the per-trait c (deep/correction/c/TRAIT_RUN.rds).
# A = P_ins3c_dry (3e-4), B = X_ins3c_2.85e-4_dry; reference the stopped 3e-5 run of lean/.
# A corrected run is the run's elasticity minus its sum of c (soil rows; COL=c_all or
# c_unsplit for the others). Scores in eps as round4/JT/nudge.R and lean/score.R. Traits
# without both c files yet are scored on what exists (an interim score).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
D <- file.path(S, "deep/correction/c"); col <- Sys.getenv("COL", "c_soil")
qa <- quantities(readRDS(file.path(S, "dev/schedtest/P_out/runs/P_ins3c_dry.rds")))
qb <- quantities(readRDS(file.path(S, "dev/schedtest/X_out/runs/X_ins3c_2.85e-4_dry.rds")))
qr <- quantities(readRDS(file.path(S, "deep/lean/L1_ref_3e-5_stop.rds")))
k <- Reduce(intersect, list(names(qa), names(qb), names(qr))); e <- eps_vec(k)
ea <- (qa[k] - qr[k]) / e; eb <- (qb[k] - qr[k]) / e; d <- (qb[k] - qa[k]) / e
tr <- k[k != "lnJ"]
got <- tr[file.exists(file.path(D, paste0(tr, "_A.rds"))) & file.exists(file.path(D, paste0(tr, "_B.rds")))]
rc <- function(t, r) readRDS(file.path(D, paste0(t, "_", r, ".rds")))
sA <- sB <- fA <- fB <- setNames(rep(0, length(k)), k)
for (t in got) { a <- rc(t, "A"); b <- rc(t, "B"); sA[t] <- sum(a$steps[[col]]); sB[t] <- sum(b$steps[[col]]); fA[t] <- a$fd_el; fB[t] <- b$fd_el }
rms <- function(x) sqrt(mean(x^2))
dc <- d - (sB - sA); eac <- ea - sA; ebc <- eb - sB
g <- c("lnJ", got); el <- got
cat(sprintf("column %s; %d of %d traits with c\n", col, length(got), length(tr)))
cat(sprintf("nudge B-A over these traits: uncorrected rms %.4f max %.4f (%s); corrected rms %.4f max %.4f (%s)\n",
  rms(d[el]), max(abs(d[el])), el[which.max(abs(d[el]))], rms(dc[el]), max(abs(dc[el])), el[which.max(abs(dc[el]))]))
cat(sprintf("  with ln J as nudge.R (%d quantities): uncorrected rms %.4f, corrected rms %.4f\n", length(g), rms(d[g]), rms(dc[g])))
cat(sprintf("  cosine of predicted (sum c(B) - sum c(A)) with measured B - A: %.3f\n", sum((sB - sA)[el] * d[el]) / sqrt(sum((sB - sA)[el]^2) * sum(d[el]^2))))
cat(sprintf("error vs reference (rms over these elasticities): A %.4f -> corrected %.4f (max %.4f %s); B %.4f -> corrected %.4f (max %.4f %s)\n",
  rms(ea[el]), rms(eac[el]), max(abs(eac[el])), el[which.max(abs(eac[el]))], rms(eb[el]), rms(ebc[el]), max(abs(ebc[el])), el[which.max(abs(ebc[el]))]))
if (length(got) == length(tr)) cat(sprintf("  all 46 elasticities: uncorrected A %.4f B %.4f (lean L1: 0.0094 / 0.0428)\n", rms(ea[tr]), rms(eb[tr])))
tab <- data.frame(trait = got, measured_AminusB = -d[got], pred_cA_minus_cB = sA[got] - sB[got], corrected_AminusB = -dc[got],
  cA = sA[got], cB = sB[got], errA = ea[got], errA_corr = eac[got], errB = eb[got], errB_corr = ebc[got],
  fd_AminusB = fA[got] - fB[got], el_AminusB = (qa[got] - qb[got]) / e[got])
options(width = 220); print(tab, digits = 3, row.names = FALSE)
saveRDS(list(col = col, tab = tab, d = d, dc = dc, ea = ea, eb = eb, sA = sA, sB = sB), file.path(dirname(D), paste0("score_", col, ".rds")))
