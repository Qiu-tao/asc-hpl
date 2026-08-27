#!/usr/bin/env bash
# 运行 HPL Baseline 并保存日志
# 用法:
#   bash run_baseline.sh             # 自动按机器内存/核数生成 HPL.dat 并跑
#   bash run_baseline.sh 30000       # 指定 N=30000
#   bash run_baseline.sh 30000 256   # 指定 N=30000, NB=256
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p logs
XHPL="$HOME/hpl-2.3/bin/ubuntu_openblas/xhpl"

if [ ! -x "$XHPL" ]; then
  echo "[错误] 没找到 $XHPL"
  echo "       请先运行: bash setup_hpl.sh"
  exit 1
fi

# 生成 HPL.dat
if [ -n "${1:-}" ]; then
  bash gen_hpl_dat.sh "$1" "${2:-192}" >/dev/null
else
  bash gen_hpl_dat.sh >/dev/null
fi

# 读取 P/Q 进程数
P=$(awk '/^[0-9]+ +Ps/{print $1; exit}' HPL.dat)
Q=$(awk '/^[0-9]+ +Qs/{print $1; exit}' HPL.dat)
NP=$((P * Q))
N=$(awk '/^[0-9]+ +Ns/{print $1; exit}' HPL.dat)

MPI_EXTRA=""
if [ "$(id -u)" -eq 0 ]; then MPI_EXTRA="--allow-run-as-root"; fi

LOG="logs/hpl_N${N}_p${NP}.log"
echo "================ HPL Baseline ================"
echo "时间: $(date)"
echo "机器: $(hostname) | 核数: $(nproc) | 内存: $(free -h | awk '/^Mem:/{print $2}')"
echo "配置: N=$N, 进程数=$NP (${P}x${Q}), 可执行文件=$XHPL"
echo "日志: $LOG"
echo "----------------------------------------------"

time bash "$(dirname "$0")/run_mpi.sh" mpirun $MPI_EXTRA -np "$NP" "$XHPL" 2>&1 | tee "$LOG"

echo "----------------------------------------------"
echo "完成。检查日志尾部: grep -E 'PASSED|FAILED|Gflops' $LOG"
