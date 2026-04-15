---
type: REF
id: REF-doc-ssot-and-archive-map
status: Draft
ontology_entity: doc-ssot-archive-governance
created: 2026-04-15
updated: 2026-04-15
---

# Docs SSOT 與 Archive Map

## 結論

目前 `Docs/` 已可分成三層：

1. `Docs/specs` / `Docs/designs` / `Docs/decisions` / `Docs/tests` / `Docs/reference`
   這是現在要保留的 canonical 區。
2. `Docs/plans`
   只保留仍在執行中的工作計畫，不當成 SSOT。
3. `Docs/archive/pre-ssot-2026-04-15`
   存放 SSOT 治理前的歷史、重構、FRD、migration 與 review 文件。

## Canonical SSOT

| 類型 | 路徑 | 說明 |
|------|------|------|
| Product Spec | `Docs/specs/` | 產品行為、流程、狀態機與 guardrail |
| Technical Design | `Docs/designs/` | how 層設計與 spec compliance |
| Decision | `Docs/decisions/` | 重大不可逆決策 |
| Test | `Docs/tests/` | 驗收場景與 QA matrix |
| Reference | `Docs/reference/` | coverage map、治理索引、cache matrix、internal surfaces map |

## 保留但非 SSOT

| 路徑 | 原因 |
|------|------|
| `Docs/plans/PLAN-onboarding-redesign-fix.md` | 仍是進行中的工作計畫，不屬於產品 SSOT，但暫不 archive |

## 本次 archive 範圍

以下內容屬於 pre-SSOT 歷史材料，保留追溯價值，但不再佔用主目錄：

- `Docs/01-architecture/`
- `Docs/02-apis/`
- `Docs/04-frds/`
- `Docs/05-impl/`
- `Docs/flutter_migration/`
- `Docs/frds/`
- `Docs/refactor/`
- `Docs/reviews/`
- `Docs/bdd/`
- `Docs/UI_FLOW_COMPLETE_GUIDE.md`
- `Docs/plans/PLAN-error-handling-refactor.md`

## 仍需補齊的文件面

下列代碼區塊仍有文件治理工作，但不一定都需要獨立 SPEC：

| 區塊 | 建議文件類型 | 狀態 |
|------|--------------|------|
| Cross-spec AC-ID 正規化 | SPEC 修訂 | 僅完成 onboarding 索引，其他 legacy spec 尚未全面補齊 |

## 本輪對齊後新增覆蓋

- App shell / global guardrail
- Heart rate / training readiness surfaces
- Workout post actions / share card
- Settings / feedback management
