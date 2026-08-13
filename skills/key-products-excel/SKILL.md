---
name: key-products-excel
description: 从“重点产品”Word文档整理产品到Excel，适用于新研博美、凯新生物等重点产品筛选、批量整理、续接上次进度并更新红色加粗截止标记。Use when the user asks to 整理重点产品、筛选产品、从Word整理产品Excel、继续上次整理、更新进度标记，or mentions 新研博美/凯新生物 and 产品名称/CAS.
---

# 重点产品 Excel 整理

## 目标

把 Word 里的重点产品按原文顺序整理成 Excel，每个品牌一个 Sheet，每批默认整理 200 个，并在源 Word 和 Excel 的截止位置做红色加粗标记，方便下次续接。

## 默认文件

- 源 Word：`D:\桌面\codex1\筛选产品\2024年重点产品筛选.docx`
- 输出 Excel：`D:\桌面\codex1\筛选产品\2024年重点产品筛选_整理.xlsx`
- 进度：`D:\桌面\codex1\筛选产品\整理进度.json`
- 累计数据：`D:\桌面\codex1\筛选产品\整理数据.json`

如果用户提供新的文件路径，用参数覆盖默认路径。

## 运行脚本

脚本位于 `scripts/整理重点产品Excel.ps1`，使用 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\整理重点产品Excel.ps1"
```

- 首次整理或需要重新从第 1 个开始：加 `-Overwrite`
- 继续整理：直接运行，脚本读取 `整理进度.json` 的 `nextStart` 自动续接
- 修改每批数量：加 `-Limit 200`
- 手动指定起点：加 `-StartNewyan 1 -StartKaixin 1`

## 整理规则

- 不排序、不保留链接、不导入图片。
- Excel 两个 Sheet：`新研博美`、`凯新生物`。
- 每行两列：`品牌`、`产品名称`。
- 产品名称用“；”分隔：英文名称；中文名称；CAS：xxxx。
- 同一行有多个名称时，优先保留一个英文名和一个中文名；没有中文名时保留两个英文名，并补充可靠的中文翻译。
- 翻译不了的中文不写，禁止编造。
- 只有 CAS 的行写成 `CAS：xxxx`。
- 多个 CAS 重复写 `CAS：a；CAS：b`。

## 续接机制

脚本会：

1. 从进度文件读取两个品牌的 `nextStart`。
2. 追加新一批产品到 `整理数据.json`。
3. 重新生成完整 Excel，并把最后一行的红色加粗标记移到本批截止行。
4. 更新 `整理进度.json`。
5. 在源 Word 里删除旧标记，并在两个品牌本批最后一条产品后插入新的红色加粗标记。

## 校验

完成后检查：

- 两个 Sheet 的行数 = 累计产品数 + 1（表头行）。
- 最后一个产品行是红色加粗。
- 产品名称中没有 `http`、`https`、`www.`。
- Word 中每个品牌截止位置后都有红色加粗进度标记。

