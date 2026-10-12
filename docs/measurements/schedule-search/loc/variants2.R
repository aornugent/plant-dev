source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
rm_ <- readRDS(file.path(L, "rowsmodel.rds"))
rows <- function(case, b) predict(rm_[[case]], data.frame(n = length(b), life = sum(39.6 - b))) / 1e3
build <- function(case, cap, rule) { p <- pilot_edges(case); ends <- sort(unique(c(0, p$edges, 39.6))); G <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; open <- p$shut((a + b) / 2) < 0.5
    hmax <- if (b <= p$b1 + 1e-9) p$b1 / 16 else cap / 365; r <- (b - a) / hmax
    n <- if (!open) 1 else switch(rule, dyadic = 2^max(0, ceiling(log2(r))), even = if (r <= 1) 1 else 2 * ceiling(r / 2), any = max(1, ceiling(r)))
    G <- c(G, seq(a, b, length.out = n + 1)) }
  G <- sort(unique(round(G, 10))); G[G < 39.6] }
for (case in c("dry", "episodic")) { cat(case, ": lattice 16/70", round(rows(case, lattice_schedule(case, 16, 70))))
  for (v in list(c(70, "dyadic"), c(70, "even"), c(80, "even"), c(70, "any"), c(100, "even"))) { G <- build(case, as.numeric(v[1]), v[2])
    cat(sprintf(" | %s %s: %d nodes %.0f", v[2], v[1], length(G), rows(case, G))) }; cat("\n") }
