# features.R: per run, the schedule's geometry against its case's pilot (edges, spells,
# gaps, founders, late intervals, the a09 proxy by band) and in-run node outputs; one row
# per distinct run (case, build, tolerance, setting, schedule), with its error vector.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
ER <- readRDS(file.path(OUT, "err.rds")); E <- ER$E; meta <- ER$meta
H <- 39.6; D <- 365
edges_of <- function(cs) { cr <- PIL[[cs]]$cr; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  st <- c(0, cr$end[e]); len <- diff(st) * D; ed <- cr$end[e][-length(e)]; closing <- op[e][-length(e)]
  k <- ed > 0 & ed < H; data.frame(b = ed[k], closing = closing[k], gap = ifelse(closing, len[-1], len[-length(len)])[k],
    spell = ifelse(closing, len[-length(len)], len[-1])[k]) }
EDG <- lapply(setNames(ALL, ALL), edges_of)
PN <- lapply(setNames(ALL, ALL), function(cs) { n <- pilot_ctx(cs)$nodes; approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2) })
feat <- function(id, cs) {
  S <- sort(RR[[id]]$S); p <- PIL[[cs]]; b1 <- p$b1; et <- EDG[[cs]]; lf <- PN[[cs]]
  lo <- head(S, -1); hi <- S[-1]; h <- hi - lo; m <- (lo + hi) / 2; open <- p$shut(m) < 0.5; w <- exp(0.6 * lf(m))
  pe <- w * h^3 * open
  band <- cut(m, c(0, b1, 10, 25, H + 1), labels = c("F", "A", "B", "L"), right = FALSE)
  # spell-end intervals: the open interval holding the point 0.1 d inside each edge before 25
  e25 <- et[et$b < 25 & et$b > b1 - 1e-9, ]
  inside <- e25$b + ifelse(e25$closing, -1, 1) * 0.1 / D
  j <- findInterval(inside, S); j[j < 1 | j > length(h)] <- NA
  at <- vapply(e25$b, function(e) min(abs(S - e)) * D < 0.5, TRUE)
  inset <- vapply(seq_len(nrow(e25)), function(i) { e <- e25$b[i]; s <- if (e25$closing[i]) S[S <= e + 1e-9 & S >= e - e25$spell[i] / D] else S[S >= e - 1e-9 & S <= e + e25$spell[i] / D]
    if (!length(s)) e25$spell[i] / 2 else min(abs(s - e)) * D }, 0)
  ingap <- vapply(seq_len(nrow(e25)), function(i) { e <- e25$b[i]; g <- e25$gap[i] / D; s <- if (e25$closing[i]) S[S > e + 0.5 / D & S < e + g - 0.5 / D] else S[S < e - 0.5 / D & S > e - g + 0.5 / D]; length(s) > 0 }, TRUE)
  hend <- ifelse(is.na(j), NA, h[j] * D); wend <- exp(0.6 * lf(e25$b))
  gapspan <- !open
  # in-run: establishment-weighted curvature of ln nrr from the run's own nodes, by class
  nrr <- RR[[id]]$nrr; cur <- NA; curE <- NA
  if (!is.null(nrr) && length(nrr) == length(S)) { y <- log(pmax(nrr, 1e-300)); k <- 2:(length(S) - 1)
    d2 <- 2 * (( y[k + 1] - y[k]) / (S[k + 1] - S[k]) - (y[k] - y[k - 1]) / (S[k] - S[k - 1])) / (S[k + 1] - S[k - 1])
    wk <- exp(y[k]) * ((S[k + 1] - S[k - 1]) / 2)^3; ok <- p$shut(S[k]) < 0.5
    cur <- sum(abs(d2[ok]) * wk[ok]) / sum(exp(y) * c(diff(S), 0))
    ek <- S[k] < 25 & vapply(S[k], function(s) min(abs(e25$b - s)) * D < 0.5, TRUE)
    curE <- sum(abs(d2[ok & ek]) * wk[ok & ek]) / sum(exp(y) * c(diff(S), 0)) }
  c(n = length(S), nF = sum(S < b1), hF_max = max(c(0, h[band == "F"])) * D, hA_med = median(h[band == "A" & open]) * D,
    hB_med = median(h[band == "B" & open]) * D, hL_max = max(h[band == "L" & open]) * D,
    proxy = sum(pe), proxyF = sum(pe[band == "F"]), proxyA = sum(pe[band == "A"]), proxyB = sum(pe[band == "B"]), proxyL = sum(pe[band == "L"]),
    nC = sum(e25$closing), nO = sum(!e25$closing), atC = sum(at & e25$closing), atO = sum(at & !e25$closing),
    insetC = mean(inset[e25$closing]), insetO = mean(inset[!e25$closing]),
    edgeC2 = sum((at * hend^2 * wend)[e25$closing], na.rm = TRUE), edgeO2 = sum((at * hend^2 * wend)[!e25$closing], na.rm = TRUE),
    insC2 = sum(((!at) * hend^2 * wend)[e25$closing], na.rm = TRUE),
    hendC = mean(hend[e25$closing], na.rm = TRUE), hendO = mean(hend[!e25$closing], na.rm = TRUE),
    ingap = sum(ingap), ngapspan = sum(gapspan & m < 25), gapw = sum((h * exp(0.6 * lf(m)))[gapspan & m < 25]),
    late_edges = sum(vapply(et$b[et$b > 25], function(e) min(abs(S - e)) * D < 0.5, TRUE)),
    cur = cur, curE = curE) }
# distinct runs
dig <- vapply(meta$id, function(i) { S <- RR[[i]]$S; sprintf("%d:%.8f", length(S), sum(S^2)) }, "")
key <- paste(meta$case, meta$build, meta$tol, meta$legacy, dig, meta$atol, meta$hmax)
keep <- !duplicated(key) & !meta$isref & meta$build %in% c("L19", "AG", "S")
meta <- meta[keep, ]; E <- E[keep, ]
F <- t(vapply(seq_len(nrow(meta)), function(i) feat(meta$id[i], meta$case[i]), numeric(28)))
colnames(F) <- names(feat(meta$id[1], meta$case[1]))
saveRDS(list(meta = meta, E = E, F = F), file.path(OUT, "feat.rds"))
cat(nrow(meta), "distinct runs\n"); print(table(meta$case, meta$build))
