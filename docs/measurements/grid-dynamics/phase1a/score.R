# Stage 1's scores for every driver run in runs/ (and the CK baselines): rows, forward
# member evaluations and a gradient run's cost against DEV/seed/tied_3e-5.rds (as
# harness/rows.R), J - J*, the soil's error against the tight monolithic recording at
# the times both runs land on, and the components that bound the accepted steps. Then
# the convergence verdict of prereg.txt per variant.
#   Rscript score.R            (writes score.csv)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
JSTAR <- 12.6687135
ref <- readRDS(file.path(D, "partition_bias/out/rec_1e-7.rds"))
base <- readRDS(file.path(D, "seed/tied_3e-5.rds"))
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))

files <- c(`base_1e-4` = file.path(D, "split/out/mono_1e-4.rds"),
           `base_3e-5` = file.path(D, "seed/tied_3e-5.rds"),
           `base_1e-5` = file.path(D, "rej/tied_1e-5_soil1.rds"))
own <- list.files(file.path(P, "runs"), "^(ck|ark)[0-9a-z]*_[0-9.e-]+\\.rds$", full.names = TRUE)
names(own) <- sub("\\.rds$", "", basename(own))
files <- c(files, own)
# ck10_3e-5 reproduced DEV/rej/tied_3e-5_soil10.rds bit for bit, so its 1e-5 rung is reused.
if (!"ck10_1e-5" %in% names(files)) files <- c(files, `ck10_1e-5` = file.path(D, "rej/tied_1e-5_soil10.rds"))

score <- function(name, f) {
  r <- readRDS(f)
  st <- r$st
  rows <- sum(as.numeric(st$M))
  fwd <- r$counts$members
  i <- match(st$time, ref$time)
  ok <- which(!is.na(i))
  d <- abs(as.matrix(st[ok, paste0("soil_", 1:5)]) - ref$soil[i[ok], ])
  kind <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  rej <- sum(unlist(r$attempts[c("rejected_inaccurate", "rejected_thrown", "rejected_refused")]))
  data.frame(run = name, variant = sub("_[^_]+$", "", name), tol = r$tol,
             accepted = nrow(st), rejected = rej, rows = rows, forward = fwd,
             rows_rel = rows / sum(as.numeric(base$st$M)) - 1,
             forward_rel = fwd / base$counts$members - 1,
             gradient_rel = (fwd / base$counts$members + 6 * rows / sum(as.numeric(base$st$M))) / 7 - 1,
             e_J = r$J / JSTAR - 1,
             soil_max = max(d), soil_med = median(apply(d, 1, max)), common = length(ok),
             bind_soil = mean(grepl("^soil_", kind)), bind_acc = mean(grepl("^accumulator_", kind)),
             bind_member = mean(kind %in% NODE), bind_storage = mean(kind == "storage"),
             x08 = mean(st$x_soil >= 0.8), x1 = mean(st$x_soil > 1),
             secs = if (is.null(r$secs)) NA else r$secs)
}
s <- do.call(rbind, Map(score, names(files), files))
s <- s[order(s$variant, -s$tol), ]
write.csv(s, file.path(P, "score.csv"), row.names = FALSE)
fmt <- within(s, {
  rows_rel <- sprintf("%+.1f%%", 100 * rows_rel); forward_rel <- sprintf("%+.1f%%", 100 * forward_rel)
  gradient_rel <- sprintf("%+.1f%%", 100 * gradient_rel); e_J <- sprintf("%+.2e", e_J)
  soil_max <- sprintf("%.2e", soil_max); soil_med <- sprintf("%.2e", soil_med)
  for (k in c("bind_soil", "bind_acc", "bind_member", "bind_storage", "x08", "x1")) assign(k, sprintf("%.1f%%", 100 * get(k)))
  secs <- round(secs)
})
options(width = 250)
print(fmt[, c("run", "accepted", "rejected", "rows", "forward", "rows_rel", "forward_rel", "gradient_rel",
              "e_J", "soil_max", "soil_med", "bind_soil", "bind_acc", "bind_member", "bind_storage", "x08", "x1", "secs")],
      row.names = FALSE)

# Convergence (prereg.txt): (a) |x(1e-5)| <= max(|x(1e-4)|/3, floor); (b) |x(3e-5)| <= 1.5 max(|x(1e-4)|, floor).
conv <- function(x, floor) {
  if (length(x) < 3 || anyNA(x)) return(NA)
  a <- abs(x[3]) <= max(abs(x[1]) / 3, floor)
  b <- abs(x[2]) <= 1.5 * max(abs(x[1]), floor)
  a && b
}
cat("\nconvergence over 1e-4, 3e-5, 1e-5 (prereg (a) and (b)):\n")
for (v in unique(s$variant)) {
  x <- s[s$variant == v, ]
  x <- x[match(c(1e-4, 3e-5, 1e-5), x$tol), ]
  cat(sprintf("  %-9s e_J %s [%s]  soil_max %s [%s]  soil_med %s [%s]\n", v,
              paste(sprintf("%+.2e", x$e_J), collapse = " "), conv(x$e_J, 6e-6),
              paste(sprintf("%.2e", x$soil_max), collapse = " "), conv(x$soil_max, 0),
              paste(sprintf("%.2e", x$soil_med), collapse = " "), conv(x$soil_med, 0)))
}
