# q2_shape.R: (a) the shape of fate over the founders' window, per node, from the lattice
# f64 runs; (b) the founders' ln J move f32 -> f64 split exactly into establishment,
# field and interpolation parts (nested pair: f32's founders are every other f64 node).
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
ALL <- c("dry", "episodic", "episodic-lma", "long-wet", "long-drought", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
st <- function(cs, f) readRDS(file.path(ADJ, sprintf("lat_%s_f%d_l70.rds", cs, f)))$stand
out <- list()
cat("(a) shape over [0, b1) on the f64 run\n")
for (cs in ALL) { x <- st(cs, 64); n <- x$nodes; b1 <- pilot_edges(cs)$b1; m <- length(n$birth)
  i <- which(n$birth < b1 - 1e-9); g <- log(n$nrr[i]); b <- n$birth[i]; S <- n$state
  lf <- log(S["fecundity", i]); mo <- S["mortality", i]; ht <- S["height", i]
  gp <- diff(g) / diff(b); bm <- (head(b, -1) + tail(b, -1)) / 2
  q <- function(lo, hi) mean(gp[bm >= lo * b1 & bm < hi * b1])
  w <- n$establishment[1:m]; share <- sum(w[i] * n$nrr[i]) / sum(w * n$nrr)
  cat(sprintf("%-13s b1 %.2f share of J %.2f | range ln nrr %.2f, ln seed output %.2f, mortality %.2f, height %.2f m | g' by fifths of [0,b1): %s | L(first fifth) %.2f y\n",
    cs, b1, share, diff(range(g)), diff(range(lf)), diff(range(mo)), diff(range(ht)),
    paste(sprintf("%+.2f", sapply(0:4, function(k) q(k / 5, (k + 1) / 5))), collapse = " "), -1 / q(0, 0.2)))
  out[[cs]] <- list(b = b, g = g, lf = lf, mo = mo, ht = ht, share = share) }
cat("\n(b) founders' move f32 -> f64 in ln J (eps units, 0.025): establishment + field + interpolation\n")
for (cs in ALL) { xf <- st(cs, 64); xc <- st(cs, 32); nf <- xf$nodes; nc <- xc$nodes; b1 <- pilot_edges(cs)$b1
  mf <- length(nf$birth); mc <- length(nc$birth); wf <- nf$establishment[1:mf]; wc <- nc$establishment[1:mc]
  key <- function(b) round(b, 8); kc <- match(key(nc$birth), key(nf$birth)); stopifnot(!anyNA(kc))
  drop <- setdiff(seq_len(mf), kc); stopifnot(all(nf$birth[drop] < b1), all(!(drop - 1) %in% drop), all(!(drop + 1) %in% drop))
  wcf <- wf; for (j in drop) { wcf[j - 1] <- wcf[j - 1] + wf[j] / 2; wcf[j + 1] <- wcf[j + 1] + wf[j] / 2 }; wcf <- wcf[kc]
  A <- sum(wf * nf$nrr)
  est <- sum((wc - wcf) * nc$nrr) / A; fld <- sum(wcf * (nc$nrr - nf$nrr[kc])) / A
  fF <- sum((wcf * (nc$nrr - nf$nrr[kc]))[nc$birth < b1]) / A
  itp <- (sum(wcf * nf$nrr[kc]) - A) / A
  tot <- xc$J / xf$J - 1
  E <- 0.025
  cat(sprintf("%-13s total %+.3f (sum of parts %+.3f) | establishment %+.3f | field %+.3f (founders' own %+.3f) | interpolation %+.3f | field/interp %+.2f | interp/J share-normalised %.2e\n",
    cs, tot / E, (est + fld + itp) / E, est / E, fld / E, fF / E, itp / E, fld / itp, itp / out[[cs]]$share))
  out[[cs]]$parts <- c(total = tot, est = est, field = fld, field_founders = fF, interp = itp) }
saveRDS(out, file.path(FO, "q2_shape.rds"))
