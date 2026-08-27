#!/usr/bin/env bash
# MPI 运行包装：临时移开 libXNVCtrl，避免 hwloc 探测 GPU 时连 X11 卡死。
#
# 背景: 某些云容器(AutoDL 等)在 127.0.0.1:6000+ 端口残留监听,
#       hwloc 探测硬件时 dlopen libXNVCtrl -> XOpenDisplay 探测 X0..X7,
#       连到残留监听后永久阻塞, 导致 mpirun/MPI_Init 卡死。
#       移开 libXNVCtrl 后 hwloc 跳过 X11 探测, 问题消失。
# 说明: 普通服务器无此问题; 本脚本在无 libXNVCtrl 时等同直接执行原命令。
#
# 用法: bash run_mpi.sh <命令...>   例如:
#        bash run_mpi.sh mpirun --allow-run-as-root -np 16 ./xhpl
set -euo pipefail

LIB=/usr/lib/x86_64-linux-gnu/libXNVCtrl.so.0
moved=0
if [ -e "$LIB" ]; then
  mv "$LIB" "$LIB.xfix.bak" 2>/dev/null && moved=1
fi

set +e
"$@"
rc=$?
set -e

if [ $moved -eq 1 ]; then
  mv "$LIB.xfix.bak" "$LIB" 2>/dev/null || true
fi
exit $rc
