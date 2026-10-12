# Each hierarchical pass's B against the reference: ln J error and its estimate sum(e)/3,
# resident elasticities in eps.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
rd2 <- function(f) if (file.exists(f)) readRDS(f)
resq <- function(o) { x <- o$stand; e <- unname(x$elasticity); names(e) <- sub("^1\\.", "", names(x$elasticity))
  v <- c(`ln J` = log(x$J), e[!names(e) %in% structural]); names(v) <- paste("resident", names(v)); v }
pair <- function(m, f) { a <- resq(m); b <- resq(f); k <- intersect(names(a), names(b)); extrap(a[k], b[k]) }
refs <- list(episodic = pair(rd2(file.path(NR, "u429_episodic.rds")), rd2(file.path(P, "u857_episodic.rds"))),
             dry = pair(rd2(file.path(NR, "u215_dry.rds")), rd2(file.path(NR, "u429_dry.rds"))),
             `long-wet` = pair(rd2(file.path(NR, "u215_long-wet.rds")), rd2(file.path(NR, "u429_long-wet.rds"))),
             `long-drought` = pair(rd2(file.path(PF, "ld_D_u215.rds")), rd2(file.path(PF, "ld_D_u429.rds"))),
             constant = pair(rd2(file.path(D, "schedtest/placed2/runs/e_cF2_constant.rds")), rd2(file.path(D, "schedtest/placed2/runs/e_cF4_constant.rds"))),
             lma = pair(rd2(file.path(D, "schedtest/placed2/runs/m_lma1252_episodic.rds")), rd2(file.path(D, "schedtest/placed2/runs/m_lma1254_episodic.rds"))))
cases <- rbind(expand.grid(tag = c("u108e", "dy"), rec = c("episodic", "dry", "long-wet", "long-drought", "constant"), stringsAsFactors = FALSE), data.frame(tag = "dylma", rec = "episodic"))
for (ci in seq_len(nrow(cases))) { tag <- cases$tag[ci]; rec <- cases$rec[ci]; ref <- refs[[if (tag == "dylma") "lma" else rec]]
  for (k in 0:6) { o <- rd2(file.path(D, "schedtest/adjmap/runs", sprintf("hier_%s_%s_p%d.rds", tag, rec, k))); if (is.null(o) || is.null(o$soil)) break
    q <- resq(o); kk <- intersect(names(q), names(ref)); kk <- kk[!endsWith(kk, nuisance)]; e <- (q[kk] - ref[kk]) / eps_vec(kk)
    b <- nd(o); j <- o$dropped; pe <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(o$light + o$soil) / o$stand$J
    cat(sprintf("%-5s %-8s p%d: B %d nodes %5.0fk rows | ln J err %+.3f, estimate %+.3f | max %.2f, median %.3f, over eps %d of %d\n", tag, rec, k,
      length(o$node_times), o$stand$rows / 1e3, e[["resident ln J"]], sum(pe) / 3 / .025, max(abs(e)), median(abs(e)), sum(abs(e) > 1), length(e))) } }
