#!/usr/bin/env bash
# HPL 环境配置 + 编译 + 小规模正确性测试
# 适用: Ubuntu 22.04/24.04 租用服务器（有 root/sudo）
# 用法: bash setup_hpl.sh 2>&1 | tee logs/setup_hpl.log
set -euo pipefail

mkdir -p "$(dirname "$0")/logs"
cd "$(dirname "$0")"
BASE_DIR=$(pwd)

echo "==================== [1/7] 机器环境 ===================="
date
echo "--- CPU 核数 ---"; nproc
echo "--- 内存 ---";     free -h | head -2
echo "--- 系统 ---";     grep PRETTY_NAME /etc/os-release

echo "==================== [2/7] 安装依赖 ===================="
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential gfortran wget make \
  libopenmpi-dev openmpi-bin \
  libopenblas-dev

echo "==================== [3/7] 下载并解压 HPL 2.3 ===================="
cd "$HOME"
if [ ! -f hpl-2.3.tar.gz ]; then
  wget -q https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz
fi
if [ ! -d hpl-2.3 ]; then
  tar -xzf hpl-2.3.tar.gz
fi
cd "$HOME/hpl-2.3"

echo "==================== [4/7] 写入 Make.ubuntu_openblas ===================="
cp "$BASE_DIR/Make.ubuntu_openblas" ./Make.ubuntu_openblas
# 检查系统路径是否与 make.inc 一致，不一致则提示
if [ ! -f /usr/lib/x86_64-linux-gnu/openmpi/include/mpi.h ]; then
  echo "[警告] 未在标准路径找到 mpi.h，请检查 libopenmpi-dev 是否安装"
fi

echo "==================== [5/7] 编译 HPL ===================="
make arch=ubuntu_openblas
ls -la bin/ubuntu_openblas/xhpl

echo "==================== [6/7] 小规模正确性测试 ===================="
cd bin/ubuntu_openblas
cat > HPL.dat <<'EOF'
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
2000         Ns
1            # of NBs
192          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
1            Ps
1            Qs
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

MPI_EXTRA=""
if [ "$(id -u)" -eq 0 ]; then MPI_EXTRA="--allow-run-as-root"; fi
echo "--- 运行 mpirun $MPI_EXTRA -np 1 ./xhpl ---"
bash "$BASE_DIR/run_mpi.sh" mpirun $MPI_EXTRA -np 1 ./xhpl 2>&1 | tee "$BASE_DIR/logs/hpl_small_test.log"

echo "==================== [7/7] 结果 ===================="
echo "检查上面日志里是否出现 PASSED / 'passed residual checks'"
echo "日志已保存: $BASE_DIR/logs/hpl_small_test.log"
echo "HPL 可执行文件: $HOME/hpl-2.3/bin/ubuntu_openblas/xhpl"
