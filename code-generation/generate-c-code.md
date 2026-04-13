---
title: Generate C Code from MATLAB (Project-Specific, Living Prompt)
description: 为 1-bit 空间DFT测角算法准备可持续更新的 MATLAB C/C++ 代码生成提示词与执行清单
tags: [matlab, code-generation, matlab-coder, c-code, isac, mimo-ofdm, 1-bit-dft]
release: Requires MATLAB Coder
notes:
---

# Generate C Code from MATLAB（本项目专用，可持续更新）

这不是一次性文档，而是“任务驱动的活文档（Living Prompt）”。
每次任务变化后，都要先更新本文件，再把其中的 Prompt 发给 AI，避免上下文漂移。

---

## 0) 每次开工前先更新这四块（强制）

1. **当前任务目标（Now Goal）**
2. **当前代码状态（Current Code State）**
3. **本轮交付物（Deliverables This Round）**
4. **验收标准（Acceptance Criteria）**

> 规则：如果这四块有任意一项过期，就先更新文档，后写代码。

---

## 1) 当前任务目标（Now Goal）

- 已完成：方案A（单比特空间DFT角度估计）
- 已完成：CA-CFAR（1D角度谱）+ 抛物线插值（峰值精化）
- 当前目标：
  1. 稳定推进 MATLAB Coder 兼容改造（先 MEX 后 C 库）
  2. 保持与当前 MATLAB 版本数值行为一致
  3. 让后续 AI 根据此文档可直接高效接管任务

---

## 2) 当前代码状态（Current Code State）

核心文件：
- `angle_1bit_dft_estimator.m`：主算法（含可选 1-bit、Bussgang、CFAR、插值）
- `run_demo_1bit_dft.m`：当前仿真入口（已打开 CFAR/插值开关）
- `joint_arv_estimator.m`：历史联合角距速版本（不作为当前 codegen 主目标）

当前 A 方案流程：
1) 可选 1-bit 量化
2) 可选 Bussgang 补偿
3) 空间维 DFT
4) 通信符号消除 + 自适应缩放因子
5) 角度谱累积
6) 可选 CA-CFAR
7) 可选抛物线插值
8) 角度反演

---

## 3) 本轮交付物（Deliverables This Round）

当你让 AI 继续推进 codegen 时，默认交付以下文件：

1. `angle_1bit_dft_estimator_codegen.m`（或直接改造原函数）
2. `build_angle_1bit_mex.m`
3. `build_angle_1bit_lib.m`
4. `test_angle_1bit_codegen.m`

可选交付：
- `compare_angle_modes.m`（全精度 / 1-bit+补偿 / 1-bit无补偿对比）

---

## 4) 验收标准（Acceptance Criteria）

基础验收：
1. MEX 可以成功生成并运行
2. 固定随机种子、固定输入下，MATLAB 与 MEX 输出一致
3. `est` 字段齐全：
   - `theta_deg, theta_rad, na_hat, na_hat_refined, peak_power, used_cfar`
4. 对固定样本，`theta_deg` 误差满足目标阈值（建议 `< 1e-9`）

进阶验收：
1. C 静态库成功生成
2. CFAR/插值开关在 codegen 下可控且行为稳定
3. 无动态字段、无不可推断可变尺寸问题

---

## 5) 后续给 AI 的推荐 Prompt（可直接复制）

```text
你现在接手的是一个“单比特空间DFT测角（方案A）”的 MATLAB 项目，请基于当前代码状态推进 MATLAB Coder 落地。

当前事实（必须遵守）：
- 主函数：angle_1bit_dft_estimator.m
- 已包含：1-bit量化、Bussgang补偿、空间DFT、通信符号消除、自适应缩放、角度谱、CA-CFAR、抛物线插值、角度反演
- demo入口：run_demo_1bit_dft.m
- 本轮目标：先MEX一致性验证，再生成C静态库

请按以下顺序输出并落地：
1) 兼容性检查（列出不利于codegen的写法）
2) 代码改造（加 %#codegen、assert、固定结构体字段、消除不确定维度）
3) 输入类型定义（coder.typeof + 有界可变尺寸）
4) 生成脚本
   - build_angle_1bit_mex.m
   - build_angle_1bit_lib.m
5) 验证脚本
   - test_angle_1bit_codegen.m（固定随机种子，比较MATLAB vs MEX）
6) 常见失败排查清单

约束：
- 不改变算法语义与开关行为
- 禁止动态扩容与运行时新增struct字段
- 复数输入保持 complex double
- 输出给出完整运行顺序

输入上界：
- y: complex double [M_rx,N_s,L], 上界 [64,2048,512]
- x: complex double [N_tx,N_s,L], 上界 [64,2048,512]
- p: 固定字段标量结构体

验收目标：
- 固定输入下 theta_deg 误差 < 1e-9
- est 字段完整且类型一致
```

---

## 6) MATLAB Coder 落地清单（执行顺序）

1. **先做 MEX**：快速检查数值一致性
2. **再做 C 静态库**：面向部署
3. **先固定维度通过**（16/16/512/128）
4. **再放开到有界可变尺寸**
5. **固定结构体字段**（`p` 字段全路径一致）
6. **固定随机种子做回归**

---

## 7) codegen 参数与 I/O 规格

输入：
- `y`: complex double `[M_rx, N_s, L]`
- `x`: complex double `[N_tx, N_s, L]`
- `p`: 标量 struct，固定字段：
  - `c, fc, dr, dt, Na, eps_div`
  - `enable_1bit_quantization, use_bussgang`
  - `enable_cfar, cfar_num_train, cfar_num_guard, cfar_pfa`
  - `enable_interp`
- `truth`: codegen 路径建议禁用打印（可传空结构或移除）

输出：
- `est`: struct
- `debug`: 如资源受限，可在 codegen 版提供精简输出

---

## 8) 常见失败与排查

1. **struct 字段不一致**：检查所有调用路径的 `p` 是否完全同构
2. **可变尺寸推断失败**：用 `coder.typeof` 给出上界
3. **复数类型漂移**：强制 `complex double`
4. **CFAR 环形索引越界**：统一 1-based + `mod` 写法
5. **MEX 与 MATLAB 微差**：先关 CFAR/插值，逐模块定位

---

## 9) 任务更新日志（每轮必须改）

- `2026-04-06`：新增 CA-CFAR 与抛物线插值；文档升级为 Living Prompt。
- 下一次更新时请补充：
  - 本轮修改文件
  - 新增脚本
  - 验收是否通过

---

## 10) 最低可用目标（MVP）

若时间紧，按以下优先级交付：
1. 无 CFAR / 无插值版本先 codegen 打通
2. MATLAB vs MEX `theta_deg` 一致
3. 再逐步启用 CFAR 与插值

这样可最快确认“单比特空间 DFT 测角”具备可部署性。
