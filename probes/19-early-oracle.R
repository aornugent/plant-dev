# The two arms differ only before canopy closure, and only in leaf area, which
# is the sole coupling.  That is the window where the oracle can speak.
suppressMessages(library(dplyr)); setwd("/home/user/plant-dev")
o <- readRDS("probes/out/oracle-ibm.rds"); st <- readRDS("probes/out/stand.rds")
g <- o$grid
h <- st[st$arm=="height",]; b <- st[st$arm=="birth-date",]
scm <- function(d, t) d$lai0[which.min(abs(d$time - t))]

ages <- c(1, 1.5, 2, 2.5, 3, 4, 5, 8)
rows <- lapply(ages, function(t) {
  j <- which.min(abs(g - t))
  r <- data.frame(age = t)
  for (a in names(o$out)) {
    L <- o$out[[a]]$L[, j, 1]
    r[[paste0("ibm", a)]] <- mean(L)
    r[[paste0("sd", a)]]  <- sd(L)
  }
  r$height <- scm(h, t); r$birth <- scm(b, t)
  r
}) |> bind_rows()
cat("=== leaf area above ground, m2/m2, before canopy closure ===\n")
print(rows[, c("age","ibm4","ibm16","ibm64","sd64","height","birth")],
      digits = 3, row.names = FALSE)
cat("\n=== ratio to IBM(area 64) ===\n")
print(data.frame(age = rows$age, height = rows$height/rows$ibm64,
                 birth = rows$birth/rows$ibm64), digits = 3, row.names = FALSE)

cat("\n=== how many plants does the IBM have there? ===\n")
for (t in c(1,2,3,5)) { j <- which.min(abs(g-t))
  cat(sprintf("  age %-4g area64: alive/m2=%.3f -> ~%.0f individuals on the patch; reps=%d\n",
      t, mean(o$out[["64"]]$N[,j]), mean(o$out[["64"]]$N[,j])*64, o$out[["64"]]$nrep)) }

cat("\n=== IBM replicate spread at area 16 (6 reps), leaf area ===\n")
for (t in c(1,2,3,5)) { j <- which.min(abs(g-t)); L <- o$out[["16"]]$L[,j,1]
  cat(sprintf("  age %-4g mean=%.4g sd=%.4g range=[%.4g, %.4g]\n", t, mean(L), sd(L), min(L), max(L))) }
