# The quantities a run is judged on, ln J and the resident's elasticities, and each one's eps:
# ln J's 0.025, an elasticity's from data/eps.csv (the across-record spread of eight seeds / 10),
# never under 0.01.
eps_tab <- read.csv(file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/data/eps.csv"))
eps_vec <- function(q) vapply(q, function(n) {
  if (n == "lnJ") return(0.025)
  e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == n & eps_tab$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }, 0)
EXCLUDED <- c("S_D", "a_f3", "recruitment_decay")
quantities <- function(x, excluded = EXCLUDED) {
  e <- unname(x$stand$elasticity); names(e) <- sub("^1\\.", "", names(x$stand$elasticity))
  c(lnJ = log(x$stand$J), e[!names(e) %in% excluded])
}
