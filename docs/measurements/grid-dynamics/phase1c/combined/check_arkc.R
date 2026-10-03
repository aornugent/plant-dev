# lib_ark's arkc (METHOD=ark, WEIGHT_SOIL=100) on long drought at 3e-5, stand
# alone and uncapped, against the driver's arkc: 9786 accepted, J 12.6425450956.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined"
x <- readRDS(file.path(C, "full/chk_arkc_ld_forward.rds"))
a <- x$stand$attempts
cat(sprintf("lib %s: J %.10f, %d accepted (%s)\n", basename(x$versions$lib), x$stand$J, a[["accepted"]],
            paste(names(a), unlist(a), sep = "=", collapse = " ")))
cat(sprintf("matches the driver's arkc (9786 accepted, J 12.6425450956 to 10 decimals): %s\n",
            a[["accepted"]] == 9786 && abs(x$stand$J - 12.6425450956) < 5e-11))
