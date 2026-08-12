# -*- coding: utf-8 -*-
"""针对 v2 新增逻辑的自测：多次运行聚合、双表导出、历史写入。"""
import os
import sys

sys.path.insert(0, r"C:\Users\liu\WorkBuddy\2026-08-07-16-30-00\baidu_index_checker")
import app

A, B = app.BRAND_A, app.BRAND_B

passed = 0
failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
        print(f"  [PASS] {name}")
    else:
        failed += 1
        print(f"  [FAIL] {name}")


# ---------- 桩：用确定性假函数替换真实搜索 ----------
state = {"calls": {}}


def fake_process(context, name, a, b, detect_fn, detect_kwargs, brand_lock=None):
    state["calls"][name] = state["calls"].get(name, 0) + 1
    i = state["calls"][name]
    if i == 1:
        return {"产品名称": name, "品牌词归类": a, "品牌词出现详情": f"{a}:3篇，{b}:1篇",
                "收录效果状态": "好", "文章链接列表": "u1，u2，u3，u4", "备注": ""}
    if i == 2:
        return {"产品名称": name, "品牌词归类": b, "品牌词出现详情": f"{a}:1篇，{b}:3篇",
                "收录效果状态": "好", "文章链接列表": "u2，u5", "备注": "1个链接无法解析"}
    return {"产品名称": name, "品牌词归类": "", "品牌词出现详情": "",
            "收录效果状态": "", "文章链接列表": "", "备注": "触发百度安全验证，请稍后重试"}


app.process_product = fake_process

print("== 场景1：run_batch 多次聚合（3次：A赢/B赢/验证） ==")
rows, links = app.run_batch(None, ["聚乙二醇"], A, B, lambda *a, **k: (False, False), {}, runs=3)
r = rows[0]
check("趋势=持平(A赢1/B赢1)", r["趋势结论"] == "持平")
check("详情含A与B", (A in r["品牌词出现详情"]) and (B in r["品牌词出现详情"]))
check("状态=差(平均总2<5)", r["收录效果状态"] == "差")
check("备注含运行次数", "共运行3次" in r["备注"])
check("备注含触发验证", "触发验证" in r["备注"])
check("链接跨运行去重合并=5条", len(links["聚乙二醇"]) == 5)

print("== 场景2：run_batch 多数决（A赢2/B赢1） ==")
state2 = {"calls": {}}


def fake2(context, name, a, b, detect_fn, detect_kwargs, brand_lock=None):
    state2["calls"][name] = state2["calls"].get(name, 0) + 1
    i = state2["calls"][name]
    if i in (1, 2):
        return {"产品名称": name, "品牌词归类": a, "品牌词出现详情": f"{a}:4篇，{b}:1篇",
                "收录效果状态": "好", "文章链接列表": "x1", "备注": ""}
    return {"产品名称": name, "品牌词归类": b, "品牌词出现详情": f"{a}:1篇，{b}:4篇",
            "收录效果状态": "好", "文章链接列表": "x2", "备注": ""}


app.process_product = fake2
rows2, _ = app.run_batch(None, ["DSPE-PEG"], A, B, lambda *a, **k: (False, False), {}, runs=3)
check("多数决归A", rows2[0]["品牌词归类"] == A)
check("趋势=多数归A", rows2[0]["趋势结论"] == A)

print("== 场景3：双表导出（结果 + 链接明细带HYPERLINK） ==")
data = app.export_workbook(rows, links)
check("xlsx 字节数>0", len(data) > 0)
# 验证确实包含两张表与超链接公式
import io
import zipfile
z = zipfile.ZipFile(io.BytesIO(data))
names = z.namelist()
check("含 xl/worksheets/sheet1.xml", "xl/worksheets/sheet1.xml" in names)
check("含 xl/worksheets/sheet2.xml", "xl/worksheets/sheet2.xml" in names)
sheet2 = z.read("xl/worksheets/sheet2.xml").decode("utf-8", "ignore")
check("链接明细含HYPERLINK公式", "HYPERLINK" in sheet2)

print("== 场景4：历史写入 ==")
meta = {"time": "t", "products": 1, "duplicates": 0, "mode": "本地", "runs": 3, "good": 1, "bad": 0}
stamp = app.save_history(app.build_output_df(rows, set()), meta)
check("返回stamp", stamp.startswith("run_"))
files = os.listdir(app.HISTORY_DIR)
check("写CSV", any(f.endswith(".csv") for f in files))
check("写JSON", any(f.endswith(".json") for f in files))
# 清理测试产生的历史文件，避免污染
for f in files:
    try:
        os.remove(os.path.join(app.HISTORY_DIR, f))
    except Exception:
        pass

print("== 场景5：模式A（品牌列指定）+ 算法1（只数指定品牌篇数） ==")
def fake_lock(context, name, a, b, detect_fn, detect_kwargs, brand_lock=None):
    if brand_lock == A:
        return {"产品名称": name, "品牌词归类": A, "品牌词出现详情": f"{A}:6篇",
                "收录效果状态": "好", "文章链接列表": "l1", "备注": "用户指定品牌，已锁定归类"}
    if brand_lock == B:
        return {"产品名称": name, "品牌词归类": B, "品牌词出现详情": f"{B}:3篇",
                "收录效果状态": "差", "文章链接列表": "l2", "备注": "用户指定品牌，已锁定归类"}
    return {"产品名称": name, "品牌词归类": "", "品牌词出现详情": "",
            "收录效果状态": "", "文章链接列表": "", "备注": "未搜索到"}


app.process_product = fake_lock
rows5a, _ = app.run_batch(None, ["聚乙二醇"], A, B, lambda *a, **k: (False, False), {}, runs=1, brand_map={"聚乙二醇": A})
check("模式A 归类锁定为A", rows5a[0]["品牌词归类"] == A)
check("模式A 详情只显示A篇数", rows5a[0]["品牌词出现详情"] == f"{A}:6篇")
check("模式A 状态按A篇数(6>=5好)", rows5a[0]["收录效果状态"] == "好")
check("模式A 趋势标注已锁定", "已锁定" in rows5a[0]["趋势结论"])
rows5b, _ = app.run_batch(None, ["DSPE-PEG"], A, B, lambda *a, **k: (False, False), {}, runs=1, brand_map={"DSPE-PEG": B})
check("模式A B指定且3篇<5→差", rows5b[0]["收录效果状态"] == "差")
check("模式A 归类锁定为B", rows5b[0]["品牌词归类"] == B)

print("== 场景6：CAS 号识别 ==")
check("CAS 识别 1159408-67-9", app.is_cas_like("1159408-67-9"))
check("CAS 识别普通产品名=False", not app.is_cas_like("聚乙二醇"))
check("CAS 识别手机号类格式=False", not app.is_cas_like("138-1234-5678"))

print("== 场景7：load_products 品牌列识别 ==")
import io as _io
import pandas as _pd
branded = _pd.DataFrame({"品牌": [A, B, ""], "产品名称": ["聚乙二醇", "DSPE-PEG", "巯基聚乙二醇"]})
buf = _io.BytesIO()
with _pd.ExcelWriter(buf, engine="openpyxl") as w:
    branded.to_excel(w, index=False)
u7, d7, bm7 = app.load_products(buf.getvalue())
check("品牌列模式 brand_map 非None", bm7 is not None)
check("品牌映射A正确", bm7.get("聚乙二醇") == A)
check("品牌映射空行视为自动", bm7.get("巯基聚乙二醇") == "")
only_prod = _pd.DataFrame({"产品名称": ["聚乙二醇", "DSPE-PEG"]})
buf2 = _io.BytesIO()
with _pd.ExcelWriter(buf2, engine="openpyxl") as w:
    only_prod.to_excel(w, index=False)
u8, d8, bm8 = app.load_products(buf2.getvalue())
check("无品牌列 brand_map 为None", bm8 is None)

print("== 场景8：多名称拆分搜索 + 链接合并去重 ==")
# 用桩替换 search_baidu，按检索词返回不同链接
fake_map = {
    "聚乙二醇": ["http://a.com/1", "http://a.com/2"],
    "PEG": ["http://a.com/2", "http://b.com/3"],          # 故意含重复
    "1159408-67-9": [],                                    # CAS 无结果
}
def fake_search(context, query, max_retry=3):
    return (fake_map.get(query, []), False)
app.search_baidu = fake_search
check("split 单名称=整体", app.split_queries("聚乙二醇") == ["聚乙二醇"])
check("split 多名称按空格", app.split_queries("聚乙二醇 1159408-67-9") == ["聚乙二醇", "1159408-67-9"])
check("split 多名称按斜杠", app.split_queries("聚乙二醇/PEG") == ["聚乙二醇", "PEG"])
check("split 整格CAS=整体", app.split_queries("1159408-67-9") == ["1159408-67-9"])

links8, blocked8, queries8 = app.search_product(None, "聚乙二醇 PEG")
# 期望合并 a.com/1, a.com/2, b.com/3，去重后3条；CAS 在另一测试
check("search_product 合并链接数=3", len(links8) == 3)
check("search_product 检索词=2", queries8 == ["聚乙二醇", "PEG"])
check("search_product 未全拦截", blocked8 is False)

links8b, blocked8b, _ = app.search_product(None, "聚乙二醇 1159408-67-9")
check("search_product 含CAS检索词=2", len(_) == 2)
check("search_product 部分无结果仍合并", len(links8b) == 2)  # 仅聚乙二醇的2条，CAS无链接

print(f"\n结果：PASS={passed}  FAIL={failed}")
sys.exit(1 if failed else 0)
