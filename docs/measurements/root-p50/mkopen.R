# Ho: H with each first-pass edge node moved inside its open window, past the root step
# of both +-2% runs by a margin; Hoea, Hoea2: edge-touching late intervals bisected.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); b1 <- 3.529
etac <- 0.5 / 365; etao <- 0.1 / 365
roots <- function(f) { cr <- as.data.frame(readRDS(file.path(Q, f))$stand$creation); pos <- cr$rate > 0; k <- which(diff(pos) != 0)
  cl <- pos[k]; i <- ifelse(cl, k, k + 1); data.frame(s = cr$start[i], e = cr$end[i], closing = cl) }
rp <- roots("rp_H_0.02_dry.rds"); rm <- roots("rp_H_-0.02_dry.rds")
cr <- readRDS(file.path(Q, "m_th0_f_dry.rds"))$stand$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
ed <- cr$end[e][-length(e)]; edcl <- op[e][-length(e)]
h <- readRDS(file.path(S, "rp50/H_dry.rds")); ho <- h; edge <- rep(FALSE, length(h)); moved <- 0
for (q in which(ed > b1)) { k <- which(abs(h - ed[q]) < 1e-9); if (!length(k)) next
  near <- function(R) { R <- R[R$closing == edcl[q], ]; R[which.min(abs((if (edcl[q]) R$e else R$s) - ed[q])), ] }
  a <- near(rp); b <- near(rm); if (abs(a$s - ed[q]) > 3 / 365 || abs(b$s - ed[q]) > 3 / 365) next
  ho[k] <- if (edcl[q]) min(a$s, b$s) - etac else max(a$e, b$e) + etao; edge[k] <- TRUE; moved <- moved + 1 }
o <- order(ho); ho <- ho[o]; edge <- edge[o]; keep <- c(TRUE, diff(ho) > 1e-4); ho <- ho[keep]; edge <- edge[keep]
bis <- function(x, isedge) { lo <- head(x, -1); hi <- x[-1]; t <- lo > b1 & (isedge[-length(x)] | isedge[-1])
  y <- c(x, (lo + hi)[t] / 2); list(x = sort(y), edge = c(isedge, rep(FALSE, sum(t)))[order(y)]) }
a1 <- bis(ho, edge); a2 <- bis(a1$x, a1$edge)
saveRDS(ho, file.path(S, "rp50/Ho_dry.rds")); saveRDS(a1$x, file.path(S, "rp50/Hoea_dry.rds")); saveRDS(a2$x, file.path(S, "rp50/Hoea2_dry.rds"))
saveRDS(ho[edge], file.path(S, "rp50/Ho_edges_dry.rds"))
cat(sprintf("edge nodes moved %d; Ho %d, Hoea %d, Hoea2 %d nodes (H %d, Hea %d, Hea2 %d)\n", moved, length(ho), length(a1$x), length(a2$x),
  length(h), length(readRDS(file.path(S, "rp50/Hea_dry.rds"))), length(readRDS(file.path(S, "rp50/Hea2_dry.rds")))))
