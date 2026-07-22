# Prototype P1 (floor) — does a FIELD-AWARE cohort schedule converge offspring in
# fewer cohorts than uniform? T3 showed the offspring error is 100% soil-water
# field-shift, concentrated at small tau_ins (early introductions dominate the
# field for the whole run). So test schedule SHAPES that put resolution where the
# field needs it, at matched cohort count, vs a dense reference:
#   default    - production schedule
#   uniform    - equal spacing (today's best)
#   early_p    - power spacing dense at small tau_ins (exponent swept)
#   field_arc  - equidistribute the pilot total-uptake field's arc length in time
#                (dense during storms/drydowns; the rainfall-as-prior variant)
# Whichever robustly beats uniform is the lever. Pure R; no production change.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
CACHE <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6, save_RK45_cache=TRUE)
PLAIN <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6)
jobs <- list(intense_storms=12, whiplash=16, extended_drought=20, dry_to_wet=20)
REF_MULT <- 4   # dense uniform reference (relative anchor; families compared at count N)

for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkp <- function(sched=NULL){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    p <- add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1)
    if (!is.null(sched)) p$node_schedule_times <- list(sort(unique(pmin(pmax(sched,0),tmax)))); p }
  Jof <- function(sched=NULL, ctrl=PLAIN){ scm <- SCM("TF24","TF24_Env")(mkp(sched), mkenv(), ctrl); scm$run()
    list(J=sum(scm$offspring_production), scm=scm) }

  # default schedule + its count N; reference = dense uniform (REF_MULT * N)
  d0 <- Jof(); baseN <- d0$scm$patch$species[[1]]$node_times; N <- length(baseN)
  Jref <- Jof(seq(0, tmax, length.out = N*REF_MULT))$J

  # pilot uptake field a(t) for field_arc: resident cache + recorded uptake
  res <- SCM("TF24","TF24_Env")(mkp(baseN), mkenv(), CACHE); res$run()
  res$set_record_uptake(TRUE); res$run_mutant(mkp(baseN))
  at <- res$uptake_times; av <- do.call(rbind, res$uptake_values)   # times x layers
  amag <- sqrt(rowSums(av^2))                                        # total uptake magnitude(t)
  # arc length of the uptake field in time; equidistribute -> N introduction times
  s <- cumsum(c(0, sqrt(diff(at)^2 + diff(amag/max(amag)*tmax)^2)))  # normalized arc
  field_arc <- approx(s/max(s), at, seq(0,1,length.out=N), rule=2, ties="ordered")$y

  # families at matched count N
  early <- function(p) tmax * (seq(0,1,length.out=N)^p)              # p>1 dense early
  fams <- list(default = baseN,
               uniform = seq(0, tmax, length.out=N),
               early1.5= early(1.5), early2 = early(2.0), early3 = early(3.0),
               field_arc = field_arc)
  cat(sprintf("\n== %s (%dyr) N=%d  Jref(uniform x%d, M=%d)=%.5e ==\n",
              nm, years, N, REF_MULT, N*REF_MULT, Jref)); flush(stdout())
  errs <- sapply(names(fams), function(fn) abs(Jof(fams[[fn]])$J - Jref)/abs(Jref))
  for (fn in names(fams)) cat(sprintf("  %-10s relerr=%.4f\n", fn, errs[fn])); flush(stdout())
  best <- names(which.min(errs))
  cat(sprintf("  => best=%s (%.4f); uniform=%.4f; default=%.4f\n",
              best, errs[best], errs["uniform"], errs["default"]))
  saveRDS(list(errs=errs, Jref=Jref, N=N), file.path(outdir, paste0("field_aware_", nm, ".rds")))
}
cat("ALLDONE\n")
