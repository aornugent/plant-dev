# cases.R: the held-out trait x climate combinations, registered as lattice.R's HELDOUT
# entries so pilot_edges(), edge_table() and pilot_of() find their pilots. Source after
# the library that defines HELDOUT.
HO_OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/heldout"
# Pilots live in HO_OUT/runs; case_of() reads file.path(RUNS, pilot), RUNS being placed2/runs.
HO_PILOT <- function(cs) file.path("../../../../deep/rootcause/heldout/runs", paste0("pilot_", cs))
HO <- list(
  `dry-lma125`    = list(rec = "dry",          seed = "",    trait = "lma=0.25",       weight = "dry"),
  `flat-al1125`   = list(rec = "dry-flat",     seed = "",    trait = "a_l1=0.25",      weight = "dry"),
  `wet-lma08`     = list(rec = "long-wet",     seed = "",    trait = "lma=-0.2",       weight = "long-wet"),
  `wet-hmat125`   = list(rec = "long-wet",     seed = "",    trait = "hmat=0.25",      weight = "long-wet"),
  `epi-hmat08`    = list(rec = "episodic",     seed = "",    trait = "hmat=-0.2",      weight = "episodic"),
  `epi-adG208`    = list(rec = "episodic",     seed = "",    trait = "a_dG2=-0.2",     weight = "episodic"),
  `ld104-p50125`  = list(rec = "long-drought", seed = "104", trait = "root_P50=0.25",  weight = "long-drought"),
  `ld107-adG2125` = list(rec = "long-drought", seed = "107", trait = "a_dG2=0.25",     weight = "long-drought"))
for (cs in names(HO)) HELDOUT[[cs]] <- c(HO[[cs]][c("rec", "trait", "seed", "weight")], list(set = "nr", pilot = HO_PILOT(cs)))
HO_RUN <- function(nm) { f <- file.path(HO_OUT, "runs", paste0(nm, ".rds")); if (file.exists(f)) readRDS(f) }
