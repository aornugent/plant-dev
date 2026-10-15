# mkmoved.R ROOTS_ERR OUT [keep|blank]: JT8's rows with each stop end moved to the
# matching f_hi root of the run whose JTROOT log is ROOTS_ERR (mkstops.R's approach:
# ordinary rows held, sizes re-differenced where a row's span changed). keep: every row
# keeps its own soil record; blank: rows whose span changed lose it. Writes OUT (a pin)
# and OUT's table of ends beside it (_ends.rds).
source("/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/held-ends/ends.R")
a <- commandArgs(TRUE); rec <- if (length(a) > 2) a[3] else "keep"
s <- readRDS(JT8)$stand; tt <- s$times
e <- stop_ends(); R <- attr(e, "roots"); P <- read_roots(a[1])

# Each θ₀ root's match: the same node and direction, nearest in time, within 3 d.
R$tp <- vapply(seq_len(nrow(R)), function(i) {
  c <- P$t[P$node == R$node[i] & P$dir == R$dir[i]]
  if (!length(c)) return(NA_real_)
  j <- which.min(abs(c - R$t[i])); if (abs(c[j] - R$t[i]) <= 3 / 365) c[j] else NA_real_ }, 0)
e$target <- vapply(e$id, function(i) { x <- R$tp[R$id == i]; x <- x[!is.na(x)]
  if (!length(x)) NA_real_ else if (e$mode[e$id == i] == "first") min(x) else max(x) }, 0)
e$target_node <- vapply(e$id, function(i) { r <- R[R$id == i & R$node == e$node[i] & R$dir == e$dir[i], ]
  if (nrow(r)) r$tp[1] else NA_real_ }, 0)
e$matched <- vapply(e$id, function(i) mean(!is.na(R$tp[R$id == i])), 0)
e$move <- e$how != "held" & !is.na(e$target)
# MAXSHIFT_D (diagnostic): move only ends within that many days whose cutting node agrees.
if (nzchar(Sys.getenv("MAXSHIFT_D"))) e$move <- e$move & abs(e$target - e$time) * 365 <= as.numeric(Sys.getenv("MAXSHIFT_D")) &
  !is.na(e$target_node) & abs(e$target_node - e$target) < 1e-6
# CAL (diagnostic): an _ends.rds of the same matching against θ₀'s own roots; move only
# ends it places within 0.05 d of where they are, and none further than 1.5 d.
if (nzchar(Sys.getenv("CAL"))) { c0 <- readRDS(Sys.getenv("CAL"))
  e$move <- e$move & !is.na(c0$shift_d) & abs(c0$shift_d) <= 0.05 & abs(e$target - e$time) * 365 <= 1.5 }
stopifnot(!anyDuplicated(e$k[e$move]))

# Times: ordinary rows held, moved ends at their targets; a target within 1e-6 yr of
# another time is held instead.
repeat {
  km <- e$k[e$move]
  other <- function(i) c(tt[-km], e$target[e$move & e$id != i])
  clash <- vapply(e$id, function(i) e$move[i] && min(abs(other(i) - e$target[i])) < 1e-6, TRUE)
  if (!any(clash)) break
  e$move[which(clash)[1]] <- FALSE
}
km <- e$k[e$move]
src <- c(setdiff(seq_along(tt), km), km)            # each new row's source row
nt <- c(tt[-km], e$target[e$move])
o <- order(nt); nt <- nt[o]; src <- src[o]
moved_row <- src %in% km
same_span <- c(TRUE, !moved_row[-1] & !moved_row[-length(nt)] & diff(src) == 1)
sz <- c(NaN, diff(nt)); sz[same_span] <- s$sizes[src[same_span]]
ni <- s$input_slopes[src]; ns <- s$substep_ends[src]
if (rec == "blank") { ni[!same_span] <- list(numeric(0)); ns[!same_span] <- list(numeric(0)) }
saveRDS(list(stand = list(times = nt, sizes = sz, input_slopes = ni, substep_ends = ns)), a[2])

e$shift_d <- (e$target - e$time) * 365
e$cross <- e$move & (e$target <= tt[e$k - 1] | e$target >= tt[e$k + 1])
saveRDS(e, sub("\\.rds$", "_ends.rds", a[2]))
q <- function(x) paste(sprintf("%.3f", quantile(x, c(0, .1, .5, .9, 1), na.rm = TRUE)), collapse = " ")
cat(sprintf("ends %d (exact %d, near %d, held unidentified %d); moved %d; held for no match %d, for a clash %d\n",
  nrow(e), sum(e$how == "exact"), sum(e$how == "near"), sum(e$how == "held"), sum(e$move),
  sum(e$how != "held" & is.na(e$target)), sum(e$how != "held" & !is.na(e$target) & !e$move)))
cat(sprintf("|shift| d of moved (0/10/50/90/100%%): %s; signed median %+.3f\n", q(abs(e$shift_d[e$move])), median(e$shift_d[e$move])))
cat(sprintf("moved before b = 25: %d, |shift| median %.3f max %.3f\n", sum(e$move & e$time < 25),
  median(abs(e$shift_d[e$move & e$time < 25])), max(abs(e$shift_d[e$move & e$time < 25]))))
cat(sprintf("cross a held neighbour: %d of %d moved\n", sum(e$cross), sum(e$move)))
cat(sprintf("cutting node's own root agrees with the set target (|diff| < 1e-6 yr): %d of %d; root-set match rate median %.2f\n",
  sum(abs(e$target_node - e$target) < 1e-6, na.rm = TRUE), sum(e$move), median(e$matched)))
cat(sprintf("rows: %d -> %d; rows whose span changed: %d (with a soil record %d)\n", length(tt), length(nt),
  sum(!same_span) - 1, sum(!same_span & lengths(s$substep_ends[src]) > 0)))
