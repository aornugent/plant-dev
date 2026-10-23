res <- readRDS(sprintf("/tmp/front/%s.rds", Sys.getenv("CASE", "closed")))
d <- res$species
print(names(d)); print(res$steps)
print(head(as.data.frame(d), 3))
print(table(d$node)[1:5]); print(length(unique(d$step))); print(range(d$time))
