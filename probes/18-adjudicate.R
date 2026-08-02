# The individual-based solver against both coordinate choices.  The IBM counts
# plants, so it cannot prefer either; its remaining bias is finite patch area,
# and the SCM is the large-area limit.
suppressMessages(library(dplyr)); setwd("/home/user/plant-dev")
o <- readRDS("probes/out/oracle-ibm.rds"); st <- readRDS("probes/out/stand.rds")
grid <- o$grid
at <- function(d, t) d[[which.min(abs(d$time - t))]]
scm_at <- function(arm, col, t) { d <- st[st$arm == arm, ]; d[[col]][which.min(abs(d$time - t))] }

ages <- c(5, 10, 20, 30, 50, 75, 100)
tab <- lapply(ages, function(t) {
  j <- which.min(abs(grid - t))
  row <- data.frame(age = t)
  for (a in names(o$out)) {
    row[[paste0("ibm", a)]] <- mean(o$out[[a]]$N[, j])
  }
  row$scm_height <- scm_at("height", "stems", t)
  row$scm_birth  <- scm_at("birth-date", "stems", t)
  row
}) |> bind_rows()
cat("=== stems per m2 ===\n"); print(tab, digits = 4, row.names = FALSE)

tab2 <- lapply(ages, function(t) {
  j <- which.min(abs(grid - t)); row <- data.frame(age = t)
  for (a in names(o$out)) row[[paste0("ibm", a)]] <- mean(o$out[[a]]$L[, j, 1])
  row$scm_height <- scm_at("height", "lai", t)
  row$scm_birth  <- scm_at("birth-date", "lai", t)
  row
}) |> bind_rows()
cat("\n=== leaf area above ground level (m2/m2) ===\n"); print(tab2, digits = 4, row.names = FALSE)

tab3 <- lapply(ages, function(t) {
  j <- which.min(abs(grid - t)); row <- data.frame(age = t)
  for (a in names(o$out)) row[[paste0("ibm", a)]] <- mean(o$out[[a]]$H[, j])
  row$scm_height <- scm_at("height", "hmax", t)
  row$scm_birth  <- scm_at("birth-date", "hmax", t)
  row
}) |> bind_rows()
cat("\n=== tallest individual (m) ===\n"); print(tab3, digits = 4, row.names = FALSE)

cat("\n=== ratio SCM / IBM(area 64), stems per m2 ===\n")
r <- data.frame(age = ages,
  height     = tab$scm_height / tab$ibm64,
  birth_date = tab$scm_birth  / tab$ibm64)
print(r, digits = 3, row.names = FALSE)
cat(sprintf("\ngeometric mean ratio over ages 20-100:  height arm %.3f   birth-date arm %.3f\n",
  exp(mean(log(r$height[r$age >= 20]))), exp(mean(log(r$birth_date[r$age >= 20])))))
cat("\nIBM stems/m2 is still rising with patch area (the SCM is the large-area\nlimit), so the birth-date arm's remaining shortfall is an upper bound.\n")
