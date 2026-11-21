#!/bin/sh
# Compiles the shaders (qml/*.frag, qml/*.vert) to .qsb: GLSL for desktop GL and for GLES
# (phones: 100 es, as Qt's own shaders, or GLES will not link ours with them), HLSL and
# MSL. Use the qsb of the Qt that runs the app (an older Qt cannot read a newer qsb).
# Usage: ./shaders.sh [path/to/qsb]
set -e
cd "$(dirname "$0")"
qsb=${1:-/usr/lib/qt6/bin/qsb}
for f in qml/*.frag qml/*.vert; do
    "$qsb" --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
done
