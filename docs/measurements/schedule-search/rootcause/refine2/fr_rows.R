# fr_rows.R: where a canonical schedule's rows go, and what each layout change would save in
# rows (CPU per row is near constant: forward 133-172, sweep 306-351 us). A node's rows are the
# accepted steps from its birth on, read from round 5's G5 run of the same case.
LIFETIME <- 40
source("/home/user/plant-dev/harness/schedule/refine.R")
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
R5R <- file.path(SP, "deep/rootcause/evidence/r5/runs")
FIVE <- c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")
count <- function(m, open, scale, plus = 2, short2 = FALSE) {
  m <- scale * m; if (!open) return(0); if (m <= 1 + 1e-9) return(if (short2) 2 else 1); 2 * ceiling(m / 2 - 1e-9) + plus }
# The schedule with each panel's count recomputed; `late` scales the panel after t90.
recount <- function(sch, scale = 1, plus = 2, short2 = FALSE, late = 1) {
  np <- length(sch$panels)
  sch$panels <- lapply(seq_len(np), function(i) { p <- sch$panels[[i]]; open <- p$n > 0
    s <- scale * if (i == np) late else 1
    p$n <- count(tail(p$mass, 1), open, s, if (i == np) 2 else plus, short2); p })
  sch }
rows_of <- function(S, t) sum(vapply(S, function(b) sum(t >= b - 1e-12), 0))
out <- list()
for (cs in FIVE) {
  f <- readRDS(file.path(SP, "refine/s1", paste0(cs, ".rds"))); sch <- f$schedule
  t <- head(readRDS(file.path(R5R, sprintf("G5_%s.rds", cs)))$stand$times, -1)
  S <- nodes_of(sch, 0); stopifnot(length(S) == f$history[[1]]$nodes); base <- rows_of(S, t)
  np <- length(sch$panels); pn <- vapply(sch$panels, `[[`, 0, "n")
  first <- sch$panels[[1]]; late <- sch$panels[[np]]
  cls <- vapply(seq_len(np), function(i) if (i == 1) "founders" else if (i == np) "late" else if (pn[i] == 1) "short" else if (pn[i] > 0) "spell" else "spell_end", "")
  share <- tapply(vapply(seq_len(np), function(i) { p <- sch$panels[[i]]
    k <- S >= p$lo - 1e-12 & S < p$hi - 1e-12; rows_of(S[k], t) }, 0), cls, sum) / base
  v <- list(scale0.7 = recount(sch, 0.7), scale0.5 = recount(sch, 0.5), no_plus2 = recount(sch, 1, 0),
            short2 = recount(sch, 1, 2, TRUE), late_half = recount(sch, 1, late = 0.5))
  rv <- vapply(v, function(s) rows_of(nodes_of(s, 0), t) / base, 0)
  nv <- vapply(v, function(s) length(nodes_of(s, 0)), 0)
  out[[cs]] <- c(nodes = length(S), round(share, 3), setNames(round(rv, 3), paste0("rows_", names(rv))), setNames(nv, paste0("n_", names(nv))))
}
print(do.call(rbind, out))
