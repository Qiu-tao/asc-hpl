#!/usr/bin/env bash
# 按机器内存/核数生成 HPL.dat（调参的第一步）
# 用法: bash gen_hpl_dat.sh [N] [NB]   （不传 N 则按内存自动估算；NB 默认 192）
set -euo pipefail

NB="${2:-192}"  # 分块大小，常见取 192 或 256
RATIO=50        # 用 50% 内存放矩阵（整数百分比），留余量给系统/面板缓冲

# ---- 内存推导 N ----
if [ -n "${1:-}" ]; then
  N=$1
else
  MEM_KB=$(free -k | awk '/^Mem:/{print $2}')
  # 容器 cgroup 内存限制优先(若有且更小)。注意: 容器里 free 常显示宿主机内存,
  # 而真正可用的是 cgroup 配额, 直接按 free 算 N 会 OOM。
  if [ -r /sys/fs/cgroup/memory.max ]; then
    CGROUP=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
    if [ "$CGROUP" != "max" ] && [ -n "$CGROUP" ]; then
      CGROUP_KB=$((CGROUP / 1024))
      [ "$CGROUP_KB" -lt "$MEM_KB" ] && MEM_KB=$CGROUP_KB
    fi
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    CGROUP=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 0)
    if [ "$CGROUP" -gt 0 ] && [ "$CGROUP" -lt 9223372036854771712 ]; then
      CGROUP_KB=$((CGROUP / 1024))
      [ "$CGROUP_KB" -lt "$MEM_KB" ] && MEM_KB=$CGROUP_KB
    fi
  fi
  N=$(awk -v kb="$MEM_KB" -v nb="$NB" -v r="$RATIO" 'BEGIN{
    n = sqrt(kb*1024*(r/100)/8);
    printf "%d", int(n/nb)*nb;   # 向下取整到 NB 的倍数
  }')
fi

# ---- 核数推导 P x Q（尽量接近正方形，且 P*Q=核数）----
# 容器 CPU 配额优先(若有且小于 nproc)。AutoDL 等容器里 nproc 显示宿主机核数,
# 实际可用是 cgroup 配额, 按 nproc 算进程数会导致严重超额订阅。
CORES=$(nproc)
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read CPU_QUOTA CPU_PERIOD < /sys/fs/cgroup/cpu.max 2>/dev/null || CPU_QUOTA=""
  if [ -n "${CPU_QUOTA:-}" ] && [ "$CPU_QUOTA" != "max" ] && [ "$CPU_QUOTA" -gt 0 ] 2>/dev/null; then
    CGROUP_CORES=$((CPU_QUOTA / CPU_PERIOD))
    [ "$CGROUP_CORES" -lt "$CORES" ] && CORES=$CGROUP_CORES
  fi
elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then
  QUOTA=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo -1)
  PERIOD=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo 100000)
  if [ "$QUOTA" -gt 0 ] 2>/dev/null; then
    CGROUP_CORES=$((QUOTA / PERIOD))
    [ "$CGROUP_CORES" -lt "$CORES" ] && CORES=$CGROUP_CORES
  fi
fi
P=1
for ((i=1; i*i<=CORES; i++)); do
  if (( CORES % i == 0 )); then P=$i; fi
done
Q=$((CORES / P))

cat > HPL.dat <<EOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
$N           Ns
1            # of NBs
$NB          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
$P           Ps
$Q           Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
2            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
2            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
0            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
0            DEPTHs (>=0)
2            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF

echo "[OK] 已生成 HPL.dat: N=$N, NB=$NB, 进程网格 ${P}x${Q}=$((P*Q))"
echo "     （矩阵大小 ≈ $((N*N*8/1024/1024/1024)) GB，用了约 ${RATIO}% 内存）"
echo "     进程数 = $((P*Q))，等于核数 $CORES"
