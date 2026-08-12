"""Generate a minimal sample .xlsx using only stdlib (no openpyxl)."""
import zipfile
import io

rows = [
    ["产品名称"],
    ["聚乙二醇"],
    ["DSPE-PEG"],
    ["巯基聚乙二醇"],
    ["荧光素"],
    ["生物素"],
    ["叶酸"],
    ["罗丹明B"],
    ["Cy3"],
    ["Cy5"],
    ["氨基聚乙二醇"],
]

# Build shared string table
shared = []
sidx = {}
def s(v):
    if v not in sidx:
        sidx[v] = len(shared)
        shared.append(v)
    return sidx[v]

cells_xml = []
for r, row in enumerate(rows, 1):
    row_xml = f'<row r="{r}">'
    for c, val in enumerate(row, 1):
        col = chr(64 + c)  # A, B, ...
        idx = s(val)
        row_xml += f'<c r="{col}{r}" t="s"><v>{idx}</v></c>'
    row_xml += '</row>'
    cells_xml.append(row_xml)

sheet_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetData>' + ''.join(cells_xml) + '</sheetData>'
    '</worksheet>'
)

sst_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="' + str(len(shared)) + '" uniqueCount="' + str(len(shared)) + '">'
    + ''.join(f'<si><t>{v}</t></si>' for v in shared)
    + '</sst>'
)

workbook_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>'
)

rels_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
    '</Relationships>'
)

root_rels_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>'
)

content_types_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
    '</Types>'
)

out = io.BytesIO()
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('[Content_Types].xml', content_types_xml)
    zf.writestr('_rels/.rels', root_rels_xml)
    zf.writestr('xl/_rels/workbook.xml.rels', rels_xml)
    zf.writestr('xl/workbook.xml', workbook_xml)
    zf.writestr('xl/worksheets/sheet1.xml', sheet_xml)
    zf.writestr('xl/sharedStrings.xml', sst_xml)

with open('sample_products.xlsx', 'wb') as f:
    f.write(out.getvalue())

print('Created sample_products.xlsx')
