#!/bin/sh
# Build and run M2 (scripts/m2_canopy_shape.cpp). Run from the plant-dev root.
#
# The probe holds develop's CanopyShape and the AD branch's templated one in one
# translation unit, and both declare plant::CanopyShape and plant::ShadingModel.
# So the branch's copy is rewritten into namespace ad_branch: its own #includes
# and include guard are stripped (the probe includes what it needs first, at
# global scope, which is what keeps std:: resolving), and what is left is wrapped.
set -e
out=${TMPDIR:-/tmp}/m2-canopy
rm -rf "$out"; mkdir -p "$out/dev/plant" "$out/ad/plant_ad"
git -C plant show origin/develop:inst/include/plant/canopy_shape.h \
  > "$out/dev/plant/canopy_shape.h"

{ echo "namespace ad_branch {"
  git -C plant show origin/claude/odelia-ad-tape-reverse-496fuf:inst/include/plant/canopy_shape.h |
    sed -e '/^#include/d' \
        -e '/^#ifndef PLANT_PLANT_CANOPY_SHAPE_H_/d' \
        -e '/^#define PLANT_PLANT_CANOPY_SHAPE_H_/d' \
        -e '${/^#endif/d;}'
  echo "}"
} > "$out/ad/plant_ad/canopy_shape.h"

rcpp_inc=$(Rscript -e 'cat(system.file("include", package="Rcpp"))')
rcpp_lib=$(Rscript -e 'cat(system.file("libs/Rcpp.so", package="Rcpp"))')
build() {
  g++ -std=c++20 -O2 -w "$@" \
    -I "$out/dev" -I "$out/ad" -I odelia/inst/include \
    -I "$rcpp_inc" -I /usr/share/R/include \
    scripts/m2_canopy_shape.cpp odelia/src/Tape.cpp \
    -L/usr/lib/R/lib -lR "$rcpp_lib"
}
build -o "$out/m2"
LD_LIBRARY_PATH=/usr/lib/R/lib "$out/m2"

# B2's second half is a compile question: can a caller reach a templated profile
# method with a double position while eta is active? Build that call on its own.
echo
echo "B2b  the double-position call, Q<double>() with an active eta:"
if build -DM2_DOUBLE_POSITION -o "$out/m2b" 2> "$out/m2b.log"; then
  echo "     it BUILDS. The number is the last column:"
  LD_LIBRARY_PATH=/usr/lib/R/lib "$out/m2b" | sed -n '/^B2 /,/^$/p' | sed 's/^/     /'
else
  echo "     it does NOT build, so the severance cannot happen silently. First error:"
  grep -m1 -B1 -A4 "error:" "$out/m2b.log" | sed 's/^/     /'
fi
