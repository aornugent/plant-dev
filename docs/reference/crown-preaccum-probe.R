# Price crown preaccumulation against the status quo. Run from /home/user/plant-dev:
#   NOT_CRAN=true Rscript docs/reference/crown-preaccum-probe.R
# Cited by docs/v3-reverse-memory-design.md 6d.
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/crown-preaccum-probe.cpp")
r <- crown_probe()
keep <- c("variant","ops","stmts","bytes","value","d_h","d_eta","d_a_p1","d_a_p2","d_src0","d_src_mid")
d <- do.call(rbind, lapply(r, function(v) as.data.frame(v[keep])))
cat("cum_bytes (run-tape cost of the cumulative sums, boundary D):",
    r[[length(r)]]$cum_bytes, "\n")
print(d, digits = 10)
cat("\ncrown bytes: full", d$bytes[1], " field-only", d$bytes[2],
    " boundary_A", d$bytes[3], "\n")
cat("field share of crown tape:", round(100 * d$bytes[2] / d$bytes[1], 1), "%\n")
for (i in 3:nrow(d)) cat(sprintf("%s factor: %.2fx\n", d$variant[i], d$bytes[1]/d$bytes[i]))
cat("\ngradient identity (full vs boundary_A):\n")
ch <- c("value", "d_h", "d_eta", "d_a_p1", "d_a_p2", "d_src0", "d_src_mid")
for (i in 3:nrow(d)) {
  cat("--", d$variant[i], "vs full --\n")
  for (k in ch) cat(sprintf("  %-10s %+.16e  %+.16e  %s\n", k, d[[k]][1], d[[k]][i],
                            ifelse(identical(d[[k]][1], d[[k]][i]), "identical",
                                   sprintf("reld %.1e", abs(d[[k]][i]/d[[k]][1]-1)))))
}
