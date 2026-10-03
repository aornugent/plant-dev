import shutil, sys, os
D = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P = os.path.join(D, "pf_nodes")
ignore = shutil.ignore_patterns(".git", "*.o", "*.so", ".claude")
for name, src in [("src_odelia", "sw_odelia"), ("src_phylloptim", "sw_phylloptim")]:
    dst = os.path.join(P, name)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(os.path.join(D, src), dst, ignore=ignore)
    print(name, len(os.listdir(dst)))
