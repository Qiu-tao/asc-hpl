# 基础题仓库 — HPL


## 基本信息（作业要求：姓名、对应题目、运行环境、复现方式）

- **姓名**：邱明涛
- **题目**：基础题 — HPL (High Performance Linpack)
- **日期**：2026/8/27
- **机器环境**：见 `env_info.txt`（由 `collect_env.sh` 生成）
- **软件版本**：OpenMPI（apt 安装）、OpenBLAS（apt 安装）、gfortran、HPL 2.3

## 复现方式

```bash
# 1. 环境配置 + 编译 + 小规模正确性测试
bash setup_hpl.sh

# 2. 生成调参后的 HPL.dat（按机器内存/核数自动估算）
bash gen_hpl_dat.sh          # 或 bash gen_hpl_dat.sh 30000 256 指定 N / NB

# 3. 运行 Baseline 并保存日志
bash run_baseline.sh
```

## 关键文件

| 文件 | 说明 |
|---|---|
| `Make.ubuntu_openblas` | HPL make.inc（OpenMPI + OpenBLAS） |
| `setup_hpl.sh` | 装依赖、编译、小规模测试 |
| `gen_hpl_dat.sh` | 按内存/核数生成 HPL.dat（N、NB、P、Q） |
| `run_baseline.sh` | 运行并 `tee` 保存日志 |
| `logs/` | 运行日志（含 PASSED/FAILED 与 GFLOP/s） |
| `env_info.txt` | 机器环境信息 |

## 结果记录

运行日志会保存到 `logs/`。关键指标在每行测试输出里：`WR00R2R2 N NB P Q 时间 Gflops`，
正确性看日志中的 `PASSED` 或 `FAILED`。

### 结果汇总表（2026-08-27 实测，AutoDL 西B区，Xeon 8352S 16核/62GB）

正式运行（Baseline 与调参）：N=50000，16 进程，OPENBLAS_NUM_THREADS=1；小规模测试为 4 进程冒烟测试。日志见 logs/。

| 组别 | N | NB | P×Q | 时间(s) | GFLOP/s | 正确性 |
|---|---|---|---|---|---|---|
| 小规模测试 | 2000 | 192 | 2×2 | 0.07 | 72.86 | PASSED |
| Baseline | 50000 | 192 | 4×4 | 114.44 | 728.25 | PASSED |
| 调参A（NB=256） | 50000 | 256 | 4×4 | 106.87 | **779.81** | PASSED |
| 调参B（2×8网格） | 50000 | 192 | 2×8 | 112.75 | 739.14 | PASSED |
| 调参C（NB=256+2×8） | 50000 | 256 | 2×8 | 114.53 | 727.64 | PASSED |

**结论**：最优为 NB=256 + 4×4，779.8 GFLOP/s，较 Baseline（728.3）提升 **+7.1%**。
分块因子 NB=256 优于 192（缓存复用更好）；进程网格 4×4 与 2×8 差别小，4×4 在 NB=256 时最优。
