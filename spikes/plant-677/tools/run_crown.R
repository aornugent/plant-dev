library(odelia); dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
Sys.setenv(PKG_CPPFLAGS="-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -O2")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "crown.cpp"), cacheDir = file.path(Sys.getenv("S"), Sys.getenv("CACHE")), rebuild = TRUE)
str(crown_cost(20000L, 8))
