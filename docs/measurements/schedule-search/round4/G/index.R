# index.R: one row per saved run across the four run directories, with its setting,
# cost, step and node counts, and quantities (ln J and elasticities) when present.
# Output: G_out/index.rds (list(meta = data.frame, q = list of named quantity vectors,
# steps = list of data.frames of accepted step times and sizes)).
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
OUT <- file.path(DEV, "schedtest/G_out")
dirs <- c(adj = "schedtest/adjmap/runs", placed2 = "schedtest/placed2/runs",
          ladder = "node_rule/ladder/runs", pf = "pf_nodes/runs")
g <- function(x, k) { v <- x[[k]]; if (is.null(v) || length(v) == 0) NA else v }
envv <- function(x, k) { e <- x$setting$env; if (is.null(e) || is.na(e[k])) NA_character_ else unname(e[k]) }
meta <- list(); Q <- list(); ST <- list()
for (d in names(dirs)) for (f in list.files(file.path(DEV, dirs[d]), "\\.rds$", full.names = TRUE)) {
  x <- tryCatch(readRDS(f), error = function(e) NULL); if (is.null(x) || !is.list(x)) next
  s <- x$stand; nm <- paste0(d, ":", sub("\\.rds$", "", basename(f)))
  if (is.null(s)) { meta[[nm]] <- data.frame(id = nm, dir = d, ok = FALSE); next }
  el <- s$elasticity
  q <- if (!is.null(s$J)) c(lnJ = log(s$J)) else c()
  if (!is.null(el)) { e <- unname(el); names(e) <- sub("^1\\.", "", names(el)); q <- c(q, e) }
  Q[[nm]] <- q
  if (!is.null(s$times)) ST[[nm]] <- data.frame(t = s$times, h = s$sizes)
  nt <- x$node_times; if (is.null(nt)) nt <- s$nodes$birth
  meta[[nm]] <- data.frame(id = nm, dir = d, ok = TRUE, mode = g(x, "mode"),
    regime = g(x$setting, "regime"), seed = g(x$setting, "seed"), tol = g(x$setting, "tol"),
    share = envv(x, "SHARE"), split = envv(x, "SPLIT"), trait = envv(x, "TRAIT_REL"),
    pin = nzchar(envv(x, "PIN") %in% c(NA, "")) & !(envv(x, "PIN") %in% c(NA, "")),
    lib = basename(envv(x, "LIB")), weight = basename(envv(x, "WEIGHT")),
    nodes = length(nt), steps = length(s$times), rows = g(s, "rows"), cpu = g(s, "cpu"),
    sweep = g(x, "sweep_cpu"), J = g(s, "J"), grad = !is.null(el),
    splits = if (is.null(s$splits)) NA else sum(s$splits),
    maxel = if (is.null(el)) NA else max(abs(el)),
    refused = !is.null(x$refusal) && length(unlist(x$refusal)) > 0,
    started = g(x, "started"))
}
meta <- do.call(rbind, lapply(meta, function(m) { for (k in c("mode","regime","seed","tol","share","split","trait","pin","lib","weight","nodes","steps","rows","cpu","sweep","J","grad","splits","maxel","refused","started")) if (is.null(m[[k]])) m[[k]] <- NA; m }))
saveRDS(list(meta = meta, q = Q, steps = ST), file.path(OUT, "index.rds"))
cat(nrow(meta), "runs;", sum(meta$grad, na.rm = TRUE), "with gradient\n")
print(table(meta$dir, meta$grad, useNA = "ifany"))
