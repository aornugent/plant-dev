# look2.R: the leading error direction per case -- shared across cases? aligned with the
# elasticities themselves? what scalar sets its amplitude?
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/G_out"
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R")); EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
X <- readRDS(file.path(OUT, "errs.rds")); m <- X$meta; E <- X$E
good <- complete.cases(E) & apply(abs(E), 1, max) < 20 & !m$pin
qn <- colnames(E); el <- setdiff(qn, "lnJ")
U <- list(); cs_all <- unique(m$case)
for (cs in cs_all) { i <- good & m$case == cs; e <- E[i, el]; s <- svd(e); u <- s$v[, 1]; if (sum(u) < 0) u <- -u
  names(u) <- el; U[[cs]] <- u
  amp <- e %*% u; lj <- E[i, "lnJ"]
  r <- X$ref[[cs]][el] / eps_vec(el)
  cat(sprintf("%-13s n=%3d  cor(amp, lnJ err)=%.2f  cos(u1, ref el/eps)=%.2f  top: %s\n", cs, sum(i), cor(amp, lj), sum(u * r) / sqrt(sum(r^2)),
    paste(sprintf("%s %.2f", names(sort(abs(u), decreasing = TRUE))[1:5], u[names(sort(abs(u), decreasing = TRUE))[1:5]]), collapse = ", "))) }
C <- sapply(U, function(a) sapply(U, function(b) sum(a * b)))
cat("\ncosine between cases' leading directions\n"); print(round(C, 2))
saveRDS(U, file.path(OUT, "u1.rds"))
