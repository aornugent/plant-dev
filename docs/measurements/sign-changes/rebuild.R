# The seventeenth extension (prereg.txt): the rebuilt split against the build it
# replaces. OUTD holds rebuild.sh's runs on NEW, OLD the thirteenth extension's
# on its LIB, and NEW102 the forward of PLANT-102 on the pinned split program,
# as committed (fwd102) and with its nodes reading TF24's cohort reads
# (fwd102c, cohort_reads.patch).
#   OUTD=... OLD=dev/p21/reads NEW102=dir Rscript rebuild.R
rd <- function(dir, f) readRDS(file.path(dir, paste0(f, ".rds")))
new <- function(f) rd(Sys.getenv("OUTD"), f)
old <- function(f) rd(Sys.getenv("OLD"), f)
new102 <- function(f) rd(Sys.getenv("NEW102"), f)
secs <- function(x, phase) x$phases[[phase]]$secs
verdict <- function(holds) if (holds) "holds" else "fails"
same <- function(a, b) identical(unname(a), unname(b))

f102 <- new102("fwd102")$stand
fo <- old("fwd_t1")$stand
per_node <- function(s) if (is.list(s$split_record)) s$split_record$split else s$splits
cat(sprintf("G1 (NEW102's forward is OLD's to the bit): J %.15g against %.15g; node steps split %d against %d, the same on every node: %s; %s\n",
            f102$J, fo$J, sum(f102$splits), sum(per_node(fo)),
            same(f102$splits[seq_along(per_node(fo))], per_node(fo)),
            verdict(identical(f102$J, fo$J) && same(f102$splits[seq_along(per_node(fo))], per_node(fo)))))
fn <- new("fwd_t1")$stand
cat(sprintf("   NEW's forward, the body the sweep shares: J %.15g, identical to OLD's %s, node by node %s\n",
            fn$J, identical(fn$J, fo$J), same(fn$splits[seq_along(per_node(fo))], per_node(fo))))

gn <- new("grad_t1")$stand
go <- old("grad_t1")$stand
differ <- names(go$gradient)[!mapply(identical, unname(gn$gradient[names(go$gradient)]),
                                     unname(go$gradient))]
cat(sprintf("G2 (the sweep is OLD's to the bit): %d of %d entries identical; J %s; %s\n",
            length(go$gradient) - length(differ), length(go$gradient),
            identical(gn$J, go$J), verdict(length(differ) == 0 && identical(gn$J, go$J))))
if (length(differ)) {
  for (n in differ) cat(sprintf("   %-28s %+.15g %+.15g\n", n, gn$gradient[[n]], go$gradient[[n]]))
}
cat(sprintf("   the elasticity in lma: %.9f\n", gn$elasticity[["1.lma"]]))

pn <- new("plain_t1")$stand
po <- old("plain_t1")$stand
fpn <- new("fwdplain_t1")$stand
fpo <- old("fwdplain_t1")$stand
cat(sprintf("G3 (off is OLD off to the bit): forward J %.15g against %.15g; the plain sweep's %d entries identical %s; %s\n",
            fpn$J, fpo$J, length(po$gradient), same(pn$gradient, po$gradient),
            verdict(identical(fpn$J, fpo$J) && identical(pn$J, po$J) && same(pn$gradient, po$gradient))))

moved <- log(f102$J) - log(fo$J)
cat(sprintf("G4, the pair rule and the counts at commit: ln J moves %.3e (G1); %s\n",
            moved, verdict(abs(moved) < 1e-8)))
fc <- new102("fwd102c")$stand
d <- log(fc$J) - log(f102$J)
cat(sprintf("G4, the cohort reads: ln J moves %+.3e, splitting %d node steps against %d (on %d nodes); %s, so they stay out\n",
            d, sum(fc$splits), sum(f102$splits), sum(fc$splits != f102$splits),
            verdict(abs(d) < 1e-8)))

w <- new("walk_split")
w3 <- new("walk_three")
cat(sprintf("G5 (J' = J): the stand %.15g, walked alone %.15g (%s), as the middle of three %.15g (%s), the three %s; %s\n",
            w$stand$J, w$invader$J, identical(w$stand$J, w$invader$J), w3$three[[2]],
            identical(w3$J, w3$three[[2]]), paste(sprintf("%.10g", w3$three), collapse = ", "),
            verdict(identical(w$stand$J, w$invader$J) && identical(w3$J, w3$alone) &&
                    identical(w3$J, w3$three[[2]]))))

g <- sapply(1:3, function(i) secs(new(sprintf("grad_t%d", i)), "stand_gradient"))
p <- sapply(1:3, function(i) secs(new(sprintf("plain_t%d", i)), "stand_gradient"))
fw <- sapply(1:2, function(i) secs(new(sprintf("fwd_t%d", i)), "stand_run"))
fp <- sapply(1:2, function(i) secs(new(sprintf("fwdplain_t%d", i)), "stand_run"))
ws <- secs(w, "invader_run")
wp <- secs(new("walk_plain"), "invader_run")
sweep <- mean(g) / mean(p) - 1
fwd <- mean(fw) / mean(fp) - 1
cat(sprintf("G6: the forward, split %s s, plain %s s: %+.1f%%, %s (at most 6%%); the sweep, split %s s, plain %s s: %+.1f%%, %s (at most 7.3%%)\n",
            paste(sprintf("%.1f", fw), collapse = ", "), paste(sprintf("%.1f", fp), collapse = ", "),
            100 * fwd, verdict(fwd <= 0.06),
            paste(sprintf("%.1f", g), collapse = ", "), paste(sprintf("%.1f", p), collapse = ", "),
            100 * sweep, verdict(sweep <= 0.073)))
cat(sprintf("    the walk of the split stand's recording %.1f s over %d rows, the plain stand's %.1f s over %d: %+.1f%% a row\n",
            ws, length(w$stand$times), wp, length(new("walk_plain")$stand$times),
            100 * ((ws / length(w$stand$times)) / (wp / length(new("walk_plain")$stand$times)) - 1)))
