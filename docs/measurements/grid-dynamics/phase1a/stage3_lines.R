# Queue lines for stage 3: a variant on the constant record (its resolved 150-node grid)
# and on episodic (108 uniform nodes), at its working tolerance, with plant replays of
# both programs for both roles' gradients, and a plant replay of the constant baseline.
#   Rscript stage3_lines.R VARIANT "METHOD=ck TOL_SOIL=100 TOL_ACC=100" 3e-5 >> queue.txt
a <- commandArgs(TRUE)
v <- a[1]; opts <- a[2]; tol <- a[3]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
CT <- file.path(D, "pi/const_times.rds")
lib <- file.path(D, "lib_guard")
cat(sprintf("s3_const_%s_%s SCRIPT=../harness_u/ark_prototype.R REGIME=constant TIMES=%s %s TOL=%s ATOL=1e-4 OUT=%s/runs/const_%s_%s.rds\n",
            v, tol, CT, opts, tol, P, v, tol))
cat(sprintf("s3_epi_%s_%s SCRIPT=../harness_u/ark_prototype.R REGIME=episodic %s TOL=%s ATOL=1e-4 OUT=%s/runs/epi_%s_%s.rds\n",
            v, tol, opts, tol, P, v, tol))
cat(sprintf("pl_epi_%s_%s SCRIPT=run_record.R PLANT_LIB=%s REGIME=episodic TOL=%s ATOL=1e-4 PROGRAM=%s/runs/epi_%s_%s.rds OUT=%s/plant/epi_%s_%s.rds\n",
            v, tol, lib, tol, P, v, tol, P, v, tol))
cat(sprintf("pl_const_%s_%s SCRIPT=run_record.R PLANT_LIB=%s REGIME=constant TIMES=%s TOL=%s ATOL=1e-4 PROGRAM=%s/runs/const_%s_%s.rds OUT=%s/plant/const_%s_%s.rds\n",
            v, tol, lib, CT, tol, P, v, tol, P, v, tol))
if (!file.exists(file.path(P, "plant/const_base_3e-5.rds")))
  cat(sprintf("pl_const_base_3e-5 SCRIPT=run_record.R PLANT_LIB=%s REGIME=constant TIMES=%s TOL=3e-5 ATOL=1e-4 PROGRAM=%s/pi/runs/const_base_3e-5.rds OUT=%s/plant/const_base_3e-5.rds\n",
              lib, CT, D, P))
