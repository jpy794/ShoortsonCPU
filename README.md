# ShoortsonCPU

## Description

A la32r(LoongArch32-Reduced) instruction set softcore microprocessor wiritten in SystemVerilog, with exception(including privillege mode) / TLB / cache(both instruction and data) support.

- 6-stage single-issue pipeline
- BTB/PHT/RAS branch predictor
- 2-radix non-restoring divider
- LRU cache
- AXI4 bus

## Getting Started

Please refer to [loongson-chiplab](https://gitee.com/loongson-edu/chiplab) for further information about simulation(with verilator) or synthesis/implemention(with Vivado).

## Known Issue

This processor is capable of booting up PEMON and Linux (before `/init`) on the dev board but gets stuck at `/init` stage.

## Authors

- @AntonioCNH
- @Chivier
- @Hyffer
- @jpy794

## About

本项目为 NSCSCC2022 LoongArch 挑战赛参赛作品.