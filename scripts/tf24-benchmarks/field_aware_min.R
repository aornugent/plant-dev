# P1 minimal (fast first read + timing): does a field-aware cohort SHAPE beat
# uniform at matched count on intense_storms? Full solves are ~110s+, and dense
# uniform may be solver-pathological, so time every run and use a 2x anchor.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
b <- readRDS("/home/user/plant-dev/scripts/tf24-benchmarks/data/intense_storms.rds")
nd <- round(12*365); rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
mkenv <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
mkp <- function(sched=NULL){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
  p <- add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1)
  if(!is.null(sched)) p$node_schedule_times <- list(sort(unique(pmin(pmax(sched,0),tmax)))); p }
PLAIN <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6)
CACHE <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6, save_RK45_cache=TRUE)
Jf <- function(sched=NULL, lab=""){ t0 <- proc.time()[3]
  scm <- SCM("TF24","TF24_Env")(mkp(sched), mkenv(), PLAIN); scm$run()
  M <- length(scm$patch$species[[1]]$node_times); J <- sum(scm$offspring_production)
  cat(sprintf("  [%-10s M=%d J=%.5e %.0fs]\n", lab, M, J, proc.time()[3]-t0)); flush(stdout()); J }
d0 <- SCM("TF24","TF24_Env")(mkp(), mkenv(), PLAIN); d0$run(); baseN <- d0$patch$species[[1]]$node_times; N <- length(baseN)
cat(sprintf("N=%d\n", N)); flush(stdout())
res <- SCM("TF24","TF24_Env")(mkp(baseN), mkenv(), CACHE); res$run(); res$set_record_uptake(TRUE); res$run_mutant(mkp(baseN))
at <- res$uptake_times; amag <- sqrt(rowSums(do.call(rbind,res$uptake_values)^2))
s <- cumsum(c(0, sqrt(diff(at)^2 + diff(amag/max(amag)*tmax)^2)))
field_arc <- approx(s/max(s), at, seq(0,1,length.out=N), rule=2, ties="ordered")$y
Jref <- Jf(seq(0,tmax,length.out=N*2), "ref2x")
fams <- list(default=baseN, uniform=seq(0,tmax,length.out=N),
             early2=tmax*(seq(0,1,length.out=N)^2), field_arc=field_arc)
cat(sprintf("Jref(2x)=%.5e\n", Jref)); flush(stdout())
for (fn in names(fams)) { Jx <- Jf(fams[[fn]], fn)
  cat(sprintf("  => %-10s relerr=%.4f\n", fn, abs(Jx-Jref)/abs(Jref))); flush(stdout()) }
cat("ALLDONE\n")
