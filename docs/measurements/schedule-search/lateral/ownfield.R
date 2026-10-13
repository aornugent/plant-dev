# Per map run: share of the drop map's |move| that is own (quadrature of fate) vs field, by region.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anysched.R"))
for (cs in names(CASES)) { b1 <- pilot_edges(cs)$b1; tot <- c(0,0,0,0,0,0)
  for (n in map_runs(cs)) { x <- run(n); if (is.null(x$light)) next; j <- x$dropped; b <- nd(x)
    own <- own_drop(b, j) / sum(b$w * b$offspring); fld <- (colSums(x$light) + colSums(x$soil)) / x$stand$J
    mid <- x$node_times[j]; r <- cut(mid, c(0, b1, 20, 40), right = FALSE)
    v <- c(tapply(abs(own), r, sum), tapply(abs(fld), r, sum)); v[is.na(v)] <- 0; tot <- tot + v }
  tot[is.na(tot)] <- 0
  cat(sprintf("%-13s own/(own+field) founders %.2f, b1-20 %.2f, >20 %.2f\n", cs, tot[1]/(tot[1]+tot[4]), tot[2]/(tot[2]+tot[5]), tot[3]/(tot[3]+tot[6]))) }
