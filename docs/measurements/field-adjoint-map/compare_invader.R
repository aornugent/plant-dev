# The invader's lma elasticity: the measured parts of its move (node_parts.R's
# elasticity_moves on the committed invader_nodes.R runs) against the drop
# probe's prediction of the field part.
#
#   Rscript compare_invader.R INV_COARSE INV_FINE [INVDROP.rds]
#
# INVDROP holds the invader on the finer schedule in the finer resident field
# with the defect of dropping the coarser grid's missing nodes added (and, if
# present, with the light defect alone). Invader nodes do not shade or drink, so
# each one's offspring is set by its birth date and the field: the coarser
# schedule's nodes are read off the finer run, weighted as INV_COARSE weights
# them.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(A, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
args <- commandArgs(TRUE)
xa <- readRDS(args[1]); xb <- readRDS(args[2])
em <- elasticity_moves(xa, xb)
el <- function(x) { J <- vapply(x$invader, `[[`, 0, "J"); (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J) }
cat(sprintf("measured: elasticity %.5f -> %.5f (net %+.4f); field %+.4f (b<0.5 %+.4f), interpolation %+.4f, establishment %+.5f\n",
            el(xa), el(xb), el(xb) - el(xa), sum(em[, "field"]), sum(em[em[, "birth"] < 0.5, "field"]),
            sum(em[, "interpolation"]), sum(em[, "establishment"])))
if (length(args) >= 3 && file.exists(args[3])) {
  d <- readRDS(args[3])
  nd <- function(x) nodes_of(list(setting = list(lifetime = 40), stand = list(nodes = x)))
  field_part <- function(pert) {
    part <- function(s) {
      a <- nd(xa$invader[[s]])                       # coarse nodes, weights and offspring in the coarse field
      fine <- nd(xb$invader[[s]]); dropped <- nd(pert$invader[[s]])
      k <- match(round(a$birth, 10), round(fine$birth, 10))
      stopifnot(!anyNA(k))
      a$w * (fine$offspring[k] - dropped$offspring[k]) / sum(a$w * a$offspring)
    }
    f <- (part("plus") - part("minus")) / (2 * xa$u)
    list(total = sum(f), top = sum(f[nd(xa$invader$plus)$birth < 0.5]))
  }
  if (!is.null(d$dropped)) {
    fp <- field_part(d$dropped)
    cat(sprintf("drop probe: invader elasticity in the finer field %.5f, with the coarser grid's defect %.5f\n",
                el(xb), d$dropped$elasticity))
    cat(sprintf("  predicted field part on the coarser invader nodes: %+.4f (b<0.5 %+.4f); measured %+.4f (b<0.5 %+.4f); ratio %.3f\n",
                fp$total, fp$top, sum(em[, "field"]), sum(em[em[, "birth"] < 0.5, "field"]), fp$total / sum(em[, "field"])))
  }
  if (!is.null(d$light)) {
    fl <- field_part(d$light)
    cat(sprintf("  light alone: %+.4f (b<0.5 %+.4f); soil (both less light) %+.4f\n", fl$total, fl$top,
                field_part(d$dropped)$total - fl$total))
  }
}
