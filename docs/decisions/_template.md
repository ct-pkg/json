---
id: D-<n>
date: <YYYY-MM-DD>
anchor: <HEAD sha>
trigger: <B-<n> / T-<n> / CR-<n> / issue id>
status: accepted
verdict: upheld
judge: EDITOR
seats:
  claim: DEV
  opposition: REVIEW
  evidence: VERIFY
scope: <受影响的 Issue / 判据 / 门禁 / 版本；若取代旧 ADR，写 `supersedes: docs/adr/000N`>
spec-claim: <C-<n>；不涉及写 `none`>
---

## 争点

<一句话写清争什么；不得写成「是否应该更好」这类无判据问题。>

## 判据（逐条）

| # | 判据 | 来源 |
| --- | --- | --- |
| 1 | <可核对的条件> | <AGENTS.md §x / 需求文档 / 命令> |

## 主张书（claim.md 索引）

`battle/<battle-id>/claim.md`

## 反证清单（counter.md 索引）

`battle/<battle-id>/counter.md`

## 出证（verify.json 索引，含命令 / 输出 / 环境）

## 判决（upheld | rejected | undecidable | escalate）

## 生效范围（范围外不得引用）

## 理由（逐条对应判据）

## 失效条件（什么情况下该决定需要重开）

## 影响面（Issue、验收判据、门禁、版本）

## 追加注记

（无则写「无」。修订只能追加在本节，格式见 [README.md](README.md#只追加不回写-a-1a-3)。）
