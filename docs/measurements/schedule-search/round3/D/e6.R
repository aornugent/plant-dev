O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
st <- c("height","mortality","fecundity","area_heartwood","mass_heartwood","storage","offspring","int_est","int_est_mom")
read_lambda <- function(f) {
  l <- grep("^LAMBDA ", readLines(f), value = TRUE)
  m <- do.call(rbind, lapply(strsplit(l, " "), function(x) as.numeric(x[-1])))
  list(d = data.frame(k = m[, 1], t = m[, 2], h = m[, 3]), L = m[, -(1:3)])
}
lab <- function(j, w) { nn <- (w - 10) / 9
  ifelse(j > 9 * nn, paste0("env", j - 9 * nn), paste0("n", (j - 1) %/% 9 + 1, ":", st[(j - 1) %% 9 + 1])) }
for (r in c("e6_n1g", "e6_n2")) {
  x <- read_lambda(paste0(O, r, ".log")); w <- ncol(x$L)
  cat("==", r, "width", w, "\n")
  for (i in seq_len(nrow(x$L))) {
    o <- order(-abs(x$L[i, ]))[1:5]
    cat(sprintf("k %d t %.6f h %.2e | env %s | top %s\n", x$d$k[i], x$d$t[i], x$d$h[i],
        paste(sprintf("%.3g", x$L[i, (w - 9):w]), collapse = " "),
        paste(sprintf("%s=%.3g", lab(o, w), x$L[i, o]), collapse = " ")))
  }
}
