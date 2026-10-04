# One forward of run_record.R's stand, for scripts/profile-gradient.sh: the
# environment run_record.R reads (PLANT_LIB, TOL, SPLIT, FORWARD=1, ...) is
# passed through, and there is nothing to cache in the unprofiled pass. OUT is
# the profile's directory there, so nothing is saved.
if (Sys.getenv("PLANT_PROFILE_PREPARE") == "1") quit(save = "no")
Sys.unsetenv("OUT")
source("harness/run_record.R")
