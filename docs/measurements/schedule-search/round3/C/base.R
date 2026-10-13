# a05_fill at its scored settings (R = 1.6, BG = 90): hfun_of, proxy_err, fill, build_graded.
if (!nzchar(Sys.getenv("R"))) Sys.setenv(R = "1.6"); if (!nzchar(Sys.getenv("BG"))) Sys.setenv(BG = "90")
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", environment())
a05_algorithm <- algorithm
widest <- function(p) build_graded(p, function(b) 1e9)
