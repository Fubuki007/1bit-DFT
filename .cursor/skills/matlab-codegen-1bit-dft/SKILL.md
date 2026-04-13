---
name: matlab-codegen-1bit-dft
description: Optimize and execute MATLAB Coder workflow for the 1-bit spatial DFT angle-estimation project. Use when user requests C/MEX generation, codegen compatibility refactor, MATLAB-vs-MEX consistency checks, or mentions generate-c-code.md, angle_1bit_dft_estimator.m, build scripts, or deployment in this repository.
---

# MATLAB Codegen for 1-bit Spatial DFT (Project Skill)

## Scope

This skill is **project-local** and must be applied only in this repository.
Target workflow: convert the existing MATLAB algorithm to MATLAB Coder-compatible implementation, then generate MEX and static C library while preserving algorithm semantics.

## Source of truth

Always treat `code-generation/generate-c-code.md` as the canonical living prompt.
Before coding, read it and align with the latest:

1. Now Goal
2. Current Code State
3. Deliverables This Round
4. Acceptance Criteria

If any of the four is stale or inconsistent with actual code, update `code-generation/generate-c-code.md` first, then implement.

## Mandatory files and context

Primary algorithm files:
- `angle_1bit_dft_estimator.m`
- `run_demo_1bit_dft.m`
- `run_mc_eval_1bit_angle.m`
- `joint_arv_estimator.m` (historical reference, not primary codegen target)

Primary generated/maintained scripts for this workflow:
- `angle_1bit_dft_estimator_codegen.m` (or codegen-safe refactor of the original)
- `build_angle_1bit_mex.m`
- `build_angle_1bit_lib.m`
- `test_angle_1bit_codegen.m`
- optional: `compare_angle_modes.m`

## Execution protocol

Follow this order:

1. Compatibility audit
   - Identify non-codegen-friendly constructs.
   - Flag dynamic struct-field creation, uncertain sizes, unsupported calls, and ambiguous complex typing.

2. Refactor for codegen
   - Add `#codegen` where appropriate.
   - Enforce fixed struct schema for `p` and output `est`.
   - Remove dynamic growth and runtime field insertion.
   - Preserve behavior of 1-bit quantization, Bussgang compensation, DFT pipeline, symbol cancellation, CA-CFAR, interpolation, and angle inversion.

3. Type specification
   - Define bounded types via `coder.typeof`.
   - Keep `y` and `x` as `complex double`.
   - Respect upper bounds from the living prompt.

4. Build scripts
   - Implement MEX build first.
   - Implement static library build second.

5. Verification
   - Fixed random seed.
   - Compare MATLAB vs MEX outputs for consistency.
   - Validate `est` fields and numeric tolerance targets.

6. Troubleshooting checklist
   - Struct-shape mismatch
   - Variable-size inference failure
   - Complex type drift
   - CFAR indexing bounds
   - Module-by-module diff isolation when mismatch occurs

## Hard constraints

- Do not change algorithmic intent or switch semantics.
- Do not introduce dynamic expansion patterns.
- Keep output field names/types stable.
- Prefer minimal, behavior-preserving edits.
- Prioritize passing MEX with fixed dimensions before bounded variable-size generalization.

## Delivery format

When finishing a task under this skill, provide:

1. Files changed/created.
2. Exact run order of scripts/commands.
3. Whether acceptance criteria passed, and any remaining blockers.
4. Suggested next smallest step if not fully complete.

## Fast-start task template

Use this checklist while working:

- [ ] Read and sync `code-generation/generate-c-code.md`
- [ ] Confirm scope and round deliverables
- [ ] Audit codegen risks in current MATLAB files
- [ ] Refactor for codegen-safe structures and sizes
- [ ] Add/update `build_angle_1bit_mex.m`
- [ ] Add/update `build_angle_1bit_lib.m`
- [ ] Add/update `test_angle_1bit_codegen.m`
- [ ] Run validation and compare MATLAB vs MEX
- [ ] Record updates back into the living prompt log
