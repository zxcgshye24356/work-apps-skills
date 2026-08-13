param(
    [string]$DocxPath = 'D:\桌面\codex1\筛选产品\2024年重点产品筛选.docx',
    [string]$XlsxPath = 'D:\桌面\codex1\筛选产品\2024年重点产品筛选_整理.xlsx',
    [string]$ProgressPath = 'D:\桌面\codex1\筛选产品\整理进度.json',
    [string]$StatePath = 'D:\桌面\codex1\筛选产品\整理数据.json',
    [int]$Limit = 200,
    [int]$StartNewyan = 1,
    [int]$StartKaixin = 1,
    [switch]$Overwrite = $false
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DocxParagraphs {
    param([string]$Path)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry('word/document.xml')
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $xml = $reader.ReadToEnd()
        $reader.Close()
    } finally {
        $zip.Dispose()
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml($xml)
    $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $paras = @()
    foreach ($p in $doc.SelectNodes('//w:p', $ns)) {
        $text = ''
        foreach ($t in $p.SelectNodes('.//w:t', $ns)) {
            $text += $t.InnerText
        }
        $paras += [pscustomobject]@{ Node = $p; Text = $text }
    }
    return ,$paras
}

function Add-Unique {
    param($List, [string]$Value)
    if ($Value -eq '') { return }
    if ($List -notcontains $Value) {
        [void]$List.Add($Value)
    }
}

function Remove-Annotations {
    param([string]$Text)
    $Text = $Text -replace '（\s*游离\s*）|\(\s*游离\s*\)', ' '
    $Text = $Text -replace '（专利产品，不发）|（专利产品）|\(专利产品，不发\)|\(专利产品\)', ' '
    $Text = $Text -replace '（甘露糖及其相关）|\(甘露糖及其相关\)', ' '
    $Text = $Text -replace '（酯键）|\(酯键\)', ' '
    $Text = $Text -replace '（以下是.*?）|\(以下是.*?\)', ' '
    $Text = $Text -replace '（建议使用.*?）|\(建议使用.*?\)', ' '
    $Text = $Text -replace '\(MW[:：]?\s*[^)]*\)|（MW[:：]?\s*[^）]*）', ' '
    return $Text
}

function Split-TopLevel {
    param([string]$Text)
    $parts = New-Object System.Collections.Generic.List[string]
    $depth = 0
    $buf = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -eq '(' -or $ch -eq '（') { $depth++ }
        elseif ($ch -eq ')' -or $ch -eq '）') { $depth = [Math]::Max(0, $depth - 1) }
        if (($ch -eq ',' -or $ch -eq '，' -or $ch -eq ';' -or $ch -eq '；') -and $depth -eq 0) {
            $part = $buf.ToString().Trim()
            if ($part -ne '') { [void]$parts.Add($part) }
            [void]$buf.Clear()
            continue
        }
        [void]$buf.Append($ch)
    }
    $last = $buf.ToString().Trim()
    if ($last -ne '') { [void]$parts.Add($last) }
    return $parts
}

function ConvertTo-ProductParts {
    param([string]$Text)
    $t = $Text -replace 'https?://\S+', ' '
    $t = $t -replace '^\s*\d+[\.、．]\s*', ''
    $t = $t -replace '\bCAS\s*#?\s*[:：]?\s*', ' '
    $t = Remove-Annotations -Text $t
    $t = $t -replace '\bMW\s*[:：]\s*\d+(\.\d+)?\s*[Kk]?(Da|da)?', ' '
    $cas = @()
    foreach ($m in [regex]::Matches($t, '\d{2,7}-\d{2}-\d')) {
        $cas += $m.Value
    }
    foreach ($c in $cas) {
        $t = $t.Replace($c, ' ')
    }
    $t = $t -replace '\(\s*\)|（\s*）', ' '
    $t = $t -replace '\s+', ' '
    $t = $t -replace 'AF488-DBCODibenzocyclooctyne', 'AF488-DBCO, Dibenzocyclooctyne'
    $t = $t -replace '6arm PEG Amine6ARM-PEG-NH2', '6arm PEG Amine, 6ARM-PEG-NH2'
    $t = $t -replace '3arm PEG Amine3ARM-PEG-NH2', '3arm PEG Amine, 3ARM-PEG-NH2'
    $t = $t -replace '(?<=[A-Za-z0-9\)])4arm', ' 4arm'
    $t = $t -replace '(?<=[A-Za-z0-9\)])8arm', ' 8arm'
    $t = $t -replace '\s+', ' '
    $t = $t -replace '(\d),(\d)', '$1~$2'
    $rawSegments = Split-TopLevel -Text $t

    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($seg in $rawSegments) {
        $seg = $seg.Replace('~', ',')
        if ($seg -match '\s/|/\s') {
            foreach ($sub in ($seg -split '\s*/\s*')) {
                $sub = $sub.Trim()
                if ($sub -ne '') { [void]$segments.Add($sub) }
            }
        } else {
            [void]$segments.Add($seg)
        }
    }

    $english = New-Object System.Collections.Generic.List[string]
    $chinese = New-Object System.Collections.Generic.List[string]
    foreach ($seg in $segments) {
        if ($seg -match '^\d+arm-(Hydroxyl|Acetic\s+Acid|Amine|Methoxy|NHS\s+Ester)$') { continue }
        if ($seg -match '^(\d+(\.\d+)?\s*[Kk]?(Da|da)?|MW[:：]?\s*\d+(\.\d+)?\s*[Kk]?(Da|da)?)$') { continue }
        if ($seg -match '^MW[:：]') { continue }
        if ($seg -match '^\d+$') { continue }
        if ($seg -match '^[（(]?MW[:：]') { continue }
        if ($seg -match '^CAS\s*#?[:：]?$') { continue }

        $hasCjk = $seg -match '[\u4e00-\u9fff]'
        $hasAscii = $seg -match '[A-Za-z]'
        if (-not $hasCjk -and -not $hasAscii) { continue }

        if ($hasCjk -and $hasAscii) {
            $m = [regex]::Match($seg, '^([A-Za-z0-9\(\)\-/]+(?:\s+[A-Za-z0-9\(\)\-/]+)*)\s+([\u4e00-\u9fff].*)$')
            if ($m.Success) {
                if ($m.Groups[1].Value.Trim() -ne '') { Add-Unique -List $english -Value $m.Groups[1].Value.Trim() }
                if ($m.Groups[2].Value.Trim() -ne '') { Add-Unique -List $chinese -Value $m.Groups[2].Value.Trim() }
            } elseif ($seg -match '^([\u4e00-\u9fff0-9\-]+)\s*[（(]\s*([A-Za-z0-9][A-Za-z0-9\-_ ()/]*)\s*[）)]$') {
                if ($Matches[1].Trim() -ne '') { Add-Unique -List $chinese -Value $Matches[1].Trim() }
                if ($Matches[2].Trim() -ne '') { Add-Unique -List $english -Value $Matches[2].Trim() }
            } else {
                Add-Unique -List $chinese -Value $seg
            }
        } elseif ($hasCjk) {
            Add-Unique -List $chinese -Value $seg
        } else {
            if ($seg -match '^\d+[- ]isomer$' -and $english.Count -gt 0) {
                $english[$english.Count - 1] = "$($english[$english.Count - 1]) $seg"
            } elseif ($seg -match "^\d+'-terminal$" -and $english.Count -gt 0) {
                $english[$english.Count - 1] = "$($english[$english.Count - 1]), $seg"
            } else {
                Add-Unique -List $english -Value $seg
            }
        }
    }

    return [pscustomobject]@{
        English = @($english)
        Chinese = @($chinese)
        CAS     = @($cas)
    }
}

function Get-ChineseTranslation {
    param([string]$Name)
    if ($Name -eq '') { return '' }
    $key = $Name.ToLowerInvariant().Trim()
    $exact = @{
        'biotin-peg24-nhs ester' = '生物素-PEG24-NHS酯'
        'biotin-peg3-hydrazide' = '生物素-PEG3-酰肼'
        'biotin-peg24-cooh' = '生物素-PEG24-羧基'
        'endo-bcn-peg2-amine' = 'endo-BCN-PEG2-氨基'
        'dbco-peg4-triethoxysilane' = 'DBCO-PEG4-三乙氧基硅烷'
        'dbco-bodipy fl' = '二苯并环辛炔-BODIPY FL'
        'sulfo-sanpah crosslinker' = '磺基-SANPAH交联剂'
        'sulfo-cyanine3 nhs ester' = '磺基花青3-NHS酯'
        '5-fam se' = '5-FAM活性酯'
        '6-fam se' = '6-FAM活性酯'
        '5-fam alkyne' = '5-FAM炔基'
        'fmoc-peg4-nhs ester' = 'Fmoc-PEG4-NHS酯'
        'fmoc-n-amido-peg4-amine' = 'Fmoc-N-酰胺-PEG4-氨基'
        'fmoc-n-amido-peg16-cooh' = 'Fmoc-N-酰胺-PEG16-羧基'
        'fluorescein-peg3-amine' = '荧光素-PEG3-氨基'
        'hydroxy-peg3-ch2cooh' = '羟基-PEG3-乙酸'
        'hydroxy-peg6-t-butyl ester' = '羟基-PEG6-叔丁基酯'
        'hydroxy-peg8t-butyl ester' = '羟基-PEG8-叔丁基酯'
        'hydroxy-peg10-t-butyl ester' = '羟基-PEG10-叔丁基酯'
        'icg-carboxylic acid icg cooh' = '吲哚菁绿-羧基'
        'icg-nhs' = '吲哚菁绿-NHS酯'
        'propargyl-peg10-acid' = '丙炔基-PEG10-羧酸'
        'icg-mal' = '吲哚菁绿-马来酰亚胺'
        'icg-alkyne' = '吲哚菁绿-炔基'
        'icg-n3' = '吲哚菁绿-叠氮'
        'ir-780 碘' = 'IR-780 碘'
        'm-peg4-ms' = 'm-PEG4-甲磺酰基'
        'nhs-s-s-nhs' = 'NHS-S-S-NHS酯'
        'mal-peg4-acid' = '马来酰亚胺-PEG4-羧酸'
        'mal-peg4-nhs ester' = '马来酰亚胺-PEG4-NHS酯'
        'n3-s-s-cooh' = 'N3-S-S-羧基'
        'n3-peg1-nh2' = '叠氮-PEG1-氨基'
        'n3-peg1-ch2cooh' = '叠氮-PEG1-乙酸'
        'n3-peg1-cooh' = '叠氮-PEG1-羧酸'
        '2-azidoethanaminehcl' = '2-叠氮乙胺盐酸盐'
        '2-azidoethanamine' = '2-叠氮乙胺'
        '3-azidopropan-1-ol' = '3-叠氮丙-1-醇'
        '3-azidopropanoic acid' = '3-叠氮丙酸'
        '7-azidoheptanoic acid' = '7-叠氮庚酸'
        '8-azido octanoic acid' = '8-叠氮辛酸'
        'azidoacetic acid nhs ester' = '叠氮乙酸-NHS酯'
        'azido-peg2-alcohol' = '叠氮-PEG2-醇'
        'n3-peg2-cooh' = '叠氮-PEG2-羧酸'
        'n3-peg2-nhs' = '叠氮-PEG2-NHS酯'
        'n3-peg3-cooh' = '叠氮-PEG3-羧酸'
        'n3-peg3-tbu' = '叠氮-PEG3-叔丁基'
        'n3-peg3-nh2' = '叠氮-PEG3-氨基'
        'icg-nh2' = '吲哚菁绿-氨基'
        'n3-peg3-alk' = '叠氮-PEG3-炔基'
        'n3-peg4-cooh' = '叠氮-PEG4-羧酸'
        'n3-peg4-nh2' = '叠氮-PEG4-氨基'
        'n3-peg4-nhs' = '叠氮-PEG4-NHS酯'
        'nh2-peg8-cooh' = '氨基-PEG8-羧酸'
        'n3-peg4-ch2cootbu' = '叠氮-PEG4-乙酸叔丁酯'
        'n3-peg5-nh2' = '叠氮-PEG5-氨基'
        'n3-peg5-nhs' = '叠氮-PEG5-NHS酯'
        'nhs-peg5-nhs' = 'NHS-PEG5-NHS酯'
        'n3-peg5-tos' = '叠氮-PEG5-对甲苯磺酰基'
        'n3-peg6-alcohol' = '叠氮-PEG6-醇'
        'n3-peg6-amine' = '叠氮-PEG6-氨基'
        'n3-peg12-nh2' = '叠氮-PEG12-氨基'
        'n3-peg6-cooh' = '叠氮-PEG6-羧酸'
        'n-boc-peg4-bromide' = 'N-Boc-PEG4-溴代'
        'n-boc-peg5-oh' = 'N-Boc-PEG5-羟基'
        'n-methyl-n-(t-boc)-peg4-acid' = 'N-甲基-N-(叔丁氧羰基)-PEG4-羧酸'
        'propargyl-peg1-acid' = '丙炔基-PEG1-羧酸'
        'propargyl-peg2-acid' = '丙炔基-PEG2-羧酸'
        'propargyl-peg2-nhboc' = '丙炔基-PEG2-NHBoc'
        'propargyl-peg4-maleimide' = '丙炔基-PEG4-马来酰亚胺'
        'propargyl-peg4-acid' = '丙炔基-PEG4-羧酸'
        'propargyl-peg4-nh2' = '丙炔基-PEG4-氨基'
        'propargyl-peg8-amine' = '丙炔基-PEG8-氨基'
        'propargyl-peg8-acid' = '丙炔基-PEG8-羧酸'
        'p-scn-bn-dota' = '对异硫氰酸苄基-DOTA'
        'fitc-biotin' = '异硫氰酸荧光素-生物素'
        '5-fam-nh2' = '5-FAM-氨基'
        'fam azide' = 'FAM叠氮'
        'fam maleimide 6-isomer' = 'FAM马来酰亚胺（6-异构体）'
        'fam alkyne' = 'FAM炔基'
        'fitc-peg-nhs' = '异硫氰酸荧光素-PEG-NHS酯'
        'fitc-peg-mal' = '异硫氰酸荧光素-PEG-马来酰亚胺'
        'mpeg-dbco' = '甲氧基PEG-DBCO'
        'mpeg-n3' = '甲氧基PEG-叠氮'
        'mpeg-nh2' = '甲氧基PEG-氨基'
        'mpeg-cooh' = '甲氧基PEG-羧基'
        'mpeg-nhs' = '甲氧基PEG-NHS酯'
        'y-peg-nhs' = 'Y型PEG-NHS酯'
        'mpeg-ac' = '甲氧基PEG-丙烯酸酯'
        'mpeg-sva' = '甲氧基PEG-琥珀酰亚胺戊酸酯'
        'mpeg-mal' = '甲氧基PEG-马来酰亚胺'
        'ohc-peg-cho' = '醛基-PEG-醛基'
        'ho-peg16-oh' = '羟基-PEG16-羟基'
        'mpeg24-oh' = '甲氧基PEG24-羟基'
        'mpeg48-oh' = '甲氧基PEG48-羟基'
        'methyl-peg9-bromide' = '甲基-PEG9-溴代'
        'methacrylate-peg2000-azide' = '甲基丙烯酸酯-PEG2000-叠氮'
        'mpeg3-mal' = '甲氧基PEG3-马来酰亚胺'
        'maca-peg-nh2' = '甲基丙烯酰胺PEG-氨基'
        'ac-peg-nhs' = '丙烯酸酯PEG-NHS酯'
        '4arm-peg-ac' = '四臂PEG-丙烯酸酯'
        'hs-peg-sh' = '巯基PEG-巯基'
        'hs-peg-cooh' = '巯基PEG-羧基'
        '4arm-peg-sh' = '四臂PEG-巯基'
        '4arm-peg-sg' = '四臂PEG-琥珀酰亚胺戊二酸酯'
        'nh2-peg-nh2' = '氨基PEG-氨基'
        'ss-peg-ss' = '琥珀酰亚胺丁二酸酯PEG-琥珀酰亚胺丁二酸酯'
        'nh2-peg-cooh' = '氨基PEG-羧基'
        'nh2-peg-sh' = '氨基PEG-巯基'
        'nhs-peg-sh' = 'NHS酯PEG-巯基'
        'nhs-peg-nhs' = 'NHS酯PEG-NHS酯'
        'n3-peg-nhs' = '叠氮PEG-NHS酯'
        'n3-peg-rb' = '叠氮PEG-罗丹明B'
        'n3-peg-cooh' = '叠氮PEG-羧基'
        'n3-peg-nh2' = '叠氮PEG-氨基'
        'hooc-peg-cooh' = '羧基PEG-羧基'
        'hooc-peg-nhs' = '羧基PEG-NHS酯'
        'mal-peg-nhs' = '马来酰亚胺PEG-NHS酯'
        'hydrazide-peg-hydrazide' = '酰肼PEG-酰肼'
        'tamra-biotin-azide' = '四甲基罗丹明-生物素-叠氮'
        '5-tamra alkyne' = '5-TAMRA炔基'
        'zinpyr-1' = 'ZINPYR-1'
        't-boc-n-amido-peg2-bromide' = 't-Boc-N-酰胺-PEG2-溴代'
        'boc-peg2-nh2' = 'Boc-PEG2-氨基'
        'nhboc-peg4-amine' = 'NHBoc-PEG4-氨基'
        'tco-nhs' = '反式环辛烯-NHS酯'
        'tco-peg4-nhs ester' = '反式环辛烯-PEG4-NHS酯'
        'tetrazine amine' = '四嗪-氨基'
        'methyltetrazine-acid' = '甲基四嗪-羧酸'
        'n-azidoacetylmannosamine-tretraacylated (ac4mannaz)' = 'N-叠氮乙酰甘露糖胺-四酰化（Ac4ManNAz）'
        'n-azidoacetylgalactosamine-tetraacylated (ac4gainaz)' = 'N-叠氮乙酰半乳糖胺-四酰化（Ac4GaINAz）'
        'benzylchlorodimethylsilane' = '苄基氯二甲基硅烷'
        'fmoc-l-ser(beta-d-glcac4)-oh' = 'Fmoc-L-丝氨酸（beta-D-GlcAc4）-OH'
        '2-azido-2-deoxy-d-glucose' = '2-叠氮-2-脱氧-D-葡萄糖'
        'dota-dbco' = 'DOTA-二苯并环辛炔'
        'nota-nhs' = 'NOTA-NHS酯'
        'p-scn-bn-nota' = '对异硫氰酸苄基-NOTA'
        'p-scn-bn-tcmc' = '对异硫氰酸苄基-TCMC'
        'dotaga-tetra (t-bu ester)' = 'DOTAGA-四叔丁基酯'
        'maleimido-mono-amide-dota' = '马来酰亚胺-单酰胺-DOTA'
        'p-scn-bn-deferoxamine' = 'p-SCN-Bn-去铁胺'
        'ggg-peg-dota' = '三甘氨酸-PEG-DOTA'
        'dbco-peg5k-nhs' = 'DBCO-PEG5K-NHS酯'
        'endo-bcn-peg4-pomalidomide' = 'endo-BCN-PEG4-泊马度胺'
        'digoxigenin nhs ester' = '地高辛配基-NHS酯'
        'dbco-peg4-nhs ester' = 'DBCO-PEG4-NHS酯'
        'dbco-peg4-biotin' = 'DBCO-PEG4-生物素'
        'sir-azide' = '硅罗丹明-叠氮'
        '6-rox-se' = '6-ROX活性酯'
        '5-tritc-scn' = '5-TRITC-异硫氰酸酯'
        '5-tamra-nhs' = '5-TAMRA-NHS酯'
        '5/6-tamra-nhs' = '5/6-TAMRA-NHS酯'
        'tamra azide 5-isomer' = 'TAMRA叠氮（5-异构体）'
        'octaarginine r8' = '八精氨酸 R8'
        'do3am-acetic acid' = 'DO3AM-乙酸'
        'p-scn-bn-dtpa' = '对异硫氰酸苄基-DTPA'
        '(2s,4r)-fmoc-amp(boc)-oh' = '(2S,4R)-Fmoc-Amp(Boc)-OH'
        '8-arm-peg-oh' = '八臂PEG-羟基'
        '8-arm-peg-nh2' = '八臂PEG-氨基'
        '8-arm-peg-aa' = '八臂PEG-乙酸'
        '8-arm-peg-sh' = '八臂PEG-巯基'
        '8-arm-peg-alkyne' = '八臂PEG-炔基'
        '8-arm-peg-n3' = '八臂PEG-叠氮'
        '8-arm-peg-ald' = '八臂PEG-丙醛'
        '8-arm-peg-ac' = '八臂PEG-丙烯酸酯'
        '8-arm-peg-aca' = '八臂PEG-丙烯酰胺'
        '8-arm-peg-mac' = '八臂PEG-甲基丙烯酸酯'
        '8-arm-peg-maca' = '八臂PEG-甲基丙烯酰胺'
        '8-arm-peg-ep' = '八臂PEG-环氧丙烷'
        '8-arm-peg-opss' = '八臂PEG-巯基吡啶'
        '8-arm-peg-hy' = '八臂PEG-酰肼'
        '8-arm-peg-scm' = '八臂PEG-琥珀酰亚胺乙酸酯'
        '8-arm-peg-sa' = '八臂PEG-丁二酸'
        '8-arm-peg-saa' = '八臂PEG-酰胺丁二酸'
        '8-arm-peg-ga' = '八臂PEG-戊二酸'
        '8-arm-peg-gaa' = '八臂PEG-酰胺戊二酸'
        '8-arm-peg-mal' = '八臂PEG-马来酰亚胺'
        '8-arm-peg-df' = '八臂PEG-苯甲醛'
        '8-arm-peg-ss' = '八臂PEG-琥珀酰亚胺丁二酸酯'
        '8-arm-peg-sas' = '八臂PEG-酰胺琥珀酰亚胺丁二酸酯'
        '8-arm-peg-sg' = '八臂PEG-琥珀酰亚胺戊二酸酯'
        '8-arm-peg-gas' = '八臂PEG-酰胺琥珀酰亚胺戊二酸酯'
        '8-arm-peg-npc' = '八臂PEG-对硝基苯酚碳酸酯'
        '8-arm-peg-nor' = '八臂PEG-降冰片烯'
        '8-arm-peg-biotin' = '八臂PEG-生物素'
        '8-arm-peg-do' = '八臂PEG-多巴胺'
        '8-arm-peg-cl' = '八臂PEG-氯'
        'dotam-bis-acid' = 'DOTAM-双羧酸'
        'dotam-nhs-ester' = 'DOTAM-NHS酯'
        'dota-lm3' = 'DOTA-LM3'
        'dota-tyr-lys-dota' = 'DOTA-酪氨酸-赖氨酸-DOTA'
        'dota-cxcr4-l' = 'DOTA-CXCR4-L'
        'dota-benzene' = 'DOTA-苯'
        'dota zoledronate' = 'DOTA-唑来膦酸盐'
        'dota-maleimide' = 'DOTA-马来酰亚胺'
        'vipivotide tetraxetan (psma-617)' = 'Vipivotide tetraxetan（PSMA-617）'
        'dusq 21 carboxylic acid' = 'DusQ 21羧酸'
        'dusq 2 phosphoramidite' = 'DusQ 2亚磷酰胺'
        'dusq 1 amidite' = 'DusQ 1亚磷酰胺'
        'dusq 1 amidite, 5''-terminal' = 'DusQ 1亚磷酰胺（5''端）'
        'dusq 2 dt phosphoramidite' = 'DusQ 2 dT亚磷酰胺'
        'dusq 1 dt phosphoramidite' = 'DusQ 1 dT亚磷酰胺'
        'norbornene-cy3' = '降冰片烯-Cy3'
        'sulfo-cy3-iodoacetamide' = '磺基-Cy3-碘乙酰胺'
        '6-af488 nhs' = '6-AF488-NHS酯'
        'cyanine3-(oh)2' = '花青3-双羟基'
        'cyanine5-(oh)2' = '花青5-双羟基'
        'cyanine7-(oh)2' = '花青7-双羟基'
        'disulfo-cy5-peg3-bcn' = '双磺基-Cy5-PEG3-BCN'
        'cyanine5 dspe' = '花青5-DSPE'
        'sulfo-cy5 bis-nhs ester' = '磺基-Cy5-双NHS酯'
        'cyanine5-peg4-nhs ester' = '花青5-PEG4-NHS酯'
        'me-tetrazine-disulfo-cyanine5' = '甲基四嗪-双磺基-花青5'
        'disulfo-cy7(ethyl)-fapi-4' = '双磺基-Cy7(乙基)-FAPI-4'
        'dota-peg5-c4-dbco' = 'DOTA-PEG5-C4-二苯并环辛炔'
        'fitc-l-glutamine' = '异硫氰酸荧光素-L-谷氨酰胺'
        'cy5 glutamine' = 'Cy5-谷氨酰胺'
        'sulfo-cy5-iodoacetamide' = '磺基-Cy5-碘乙酰胺'
        'pomalidomide-nh-peg4-amine' = '泊马度胺-NH-PEG4-氨基'
        'af488 nhs' = 'AF488-NHS酯'
        'dota-jr11' = 'DOTA-JR11'
        'dota-biotin' = 'DOTA-生物素'
        'dota-noc' = 'DOTA-NOC'
        'dota derivative' = 'DOTA衍生物'
        'dota-peg5-c6-dbco' = 'DOTA-PEG5-C6-二苯并环辛炔'
        'do3a-tert-butyl ester' = 'DO3A-叔丁基酯'
        '3bp-3940' = '3BP-3940'
        'nh2-peg-mannose' = '氨基PEG-甘露糖'
        'hs-peg-mannose' = '巯基PEG-甘露糖'
        'nhs-peg-mannose' = 'NHS酯PEG-甘露糖'
        'biotin-ss-nhs ester' = '生物素-SS-NHS酯'
        'y-shaped peg-ac' = 'Y型PEG-丙烯酸酯'
        'y-shaped peg-alkyne' = 'Y型PEG-炔基'
        'y-shaped peg-cho' = 'Y型PEG-醛基'
        'y-shaped peg-cooh' = 'Y型PEG-羧基'
        'y-shaped peg-ma' = 'Y型PEG-甲基丙烯酸酯'
        'y-shaped peg-mal' = 'Y型PEG-马来酰亚胺'
        'y-shaped peg-n3' = 'Y型PEG-叠氮'
        'y-shaped peg-nco' = 'Y型PEG-异氰酸酯'
        'y-shaped peg-nh2' = 'Y型PEG-氨基'
        'y-shaped peg-sc' = 'Y型PEG-琥珀酰亚胺酯'
        'y-shaped peg-scm' = 'Y型PEG-琥珀酰亚胺羧甲基酯'
        'y-shaped peg-sh' = 'Y型PEG-巯基'
        'y-shaped peg-spa' = 'Y型PEG-琥珀酰亚胺丙酸酯'
        'desthiobiotin-iodoacetamide' = '脱硫生物素-碘乙酰胺'
        'thp(bz3)-glu' = 'THP(Bz3)-Glu'
        'thp-scn' = 'THP-SCN'
        'thp(bz)3-nh2' = 'THP(Bz)3-NH2'
        'fluorescein tyramide' = '荧光素-酪胺'
        'cyanine3 phosphoramidite' = '花青3-亚磷酰胺'
        'cyanine5 phosphoramidite' = '花青5-亚磷酰胺'
        'cyanine7 phosphoramidite' = '花青7-亚磷酰胺'
        'thalidomide-c8-nh2' = '沙利度胺-C8-氨基'
        'bdp r6g nhs ester' = 'BDP R6G-NHS酯'
        'bis-peg25-nhs ester' = '双PEG25-NHS酯'
        'sir-cooh' = '硅罗丹明-羧基'
        'af 343 (coumarin) x nhs ester' = 'AF 343（香豆素）X-NHS酯'
        'af 488 tfp ester' = 'AF 488-TFP酯'
        'hex nhs ester 6-isomer' = 'HEX-NHS酯（6-异构体）'
        'joe nhs ester 5-isomer' = 'JOE-NHS酯（5-异构体）'
        'pyrenebutyric acid nhs ester' = '芘丁酸-NHS酯'
        'af 555 azide' = 'AF 555-叠氮'
        'af 594 azide' = 'AF 594-叠氮'
        'att 565 azide' = 'ATT 565-叠氮'
        'att 594 azide' = 'ATT 594-叠氮'
        'fam azide 5-isomer' = 'FAM叠氮（5-异构体）'
        'fam azide 6-isomer' = 'FAM叠氮（6-异构体）'
        'vic azide 6-isomer' = 'VIC叠氮（6-异构体）'
        '1-ethynyl pyrene' = '1-乙炔基芘'
        '3-ethynyl perylene' = '3-乙炔基苝'
        'pyrene maleimide' = '芘-马来酰亚胺'
        'af 430 hydrazide' = 'AF 430-酰肼'
        'af 488 hydrazide' = 'AF 488-酰肼'
        'fam hydrazide 5-isomer' = 'FAM酰肼（5-异构体）'
        'fam hydrazide 6-isomer' = 'FAM酰肼（6-异构体）'
        'pyrene hydrazide' = '芘-酰肼'
        'rox nh2' = 'ROX-氨基'
        'af 568 dbco' = 'AF 568-DBCO'
        '3,5-dimethyl-bdp' = '3,5-二甲基-BDP'
        'bdp fl l-cystine' = 'BDP FL-L-胱氨酸'
        'technodye 498/505' = 'TechnoDye 498/505'
        'technodye 502/512' = 'TechnoDye 502/512'
        'dbco-peg2-amine' = 'DBCO-PEG2-氨基'
        'atp-red 1' = 'ATP-Red 1'
        'af 488 dbco' = 'AF 488-二苯并环辛炔'
        'fapi-46' = 'FAPI-46'
        'dspe-peg-dbco' = '二硬脂酰磷脂酰乙醇胺-PEG-DBCO'
        'af488 azide' = 'AF488-叠氮'
        'af 568 azide' = 'AF 568-叠氮'
        'pyrene azide 2' = '芘-叠氮（2）'
        'af 568 alkyne' = 'AF 568-炔基'
        'af 430 amine' = 'AF 430-氨基'
        'af 488 amine' = 'AF 488-氨基'
        'af 430 tetrazine' = 'AF 430-四嗪'
        'bdp 576/589 tetrazine' = 'BDP 576/589-四嗪'
        'bdp fl tetrazine' = 'BDP FL-四嗪'
        'rox tetrazine 5-isomer' = 'ROX-四嗪（5-异构体）'
        'oxabiphor acid' = 'Oxabiphor酸'
        'y-peg-mal' = 'Y型PEG-马来酰亚胺'
        'y-peg-cooh' = 'Y型PEG-羧基'
        'y-peg-aald' = 'Y型PEG-醛'
        'y-peg-pald' = 'Y型PEG-丙醛'
        'y-peg-alkyne' = 'Y型PEG-炔基'
        'y-peg-nh2' = 'Y型PEG-氨基'
        'y-peg-fitc' = 'Y型PEG-异硫氰酸荧光素'
        '6arm peg amine6arm-peg-nh2' = '六臂PEG-氨基（6ARM-PEG-NH2）'
        '3arm peg amine3arm-peg-nh2' = '三臂PEG-氨基（3ARM-PEG-NH2）'
        'at 488 acid' = 'AT 488-羧酸'
        '(ho)3-4armpeg-cm4arm peg' = '三羟基四臂PEG-羧甲基'
        '(ho)3-4armpeg-nh2hcl4arm peg' = '三羟基四臂PEG-氨基盐酸盐'
        '(ho)2-4armpeg-(cm)24arm peg' = '二羟基四臂PEG-二羧甲基'
        '(ho)2-4armpeg-(nh2hcl)24arm peg' = '二羟基四臂PEG-二氨基盐酸盐'
        'ho-4armpeg-(cm)34arm peg' = '单羟基四臂PEG-三羧甲基'
        'azido-peg8-nhs' = '叠氮-PEG8-NHS酯'
        'silane-peg4-dbco' = '硅烷-PEG4-DBCO'
        'm-peg-scm' = '甲氧基PEG-琥珀酰亚胺乙酸酯'
        'm-peg-cm' = '甲氧基PEG-羧甲基'
        'ho-4armpeg-(cm)3 4arm peg' = '单羟基四臂PEG-三羧甲基'
        '(ho)3-4armpeg-cm 4arm peg' = '三羟基四臂PEG-羧甲基'
        '(ho)3-4armpeg-nh2hcl 4arm peg' = '三羟基四臂PEG-氨基盐酸盐'
        '(ho)2-4armpeg-(cm)2 4arm peg' = '二羟基四臂PEG-二羧甲基'
        '(ho)2-4armpeg-(nh2hcl)2 4arm peg' = '二羟基四臂PEG-二氨基盐酸盐'
        '(ch3o)3-4armpeg-scm 4arm-peg' = '三甲氧基四臂PEG-琥珀酰亚胺乙酸酯'
        '6arm peg amine' = '六臂PEG-氨基'
        '3arm peg amine' = '三臂PEG-氨基'
        'nh2-peg4-ch2cootbu' = '氨基-PEG4-乙酸叔丁酯'
    }
    if ($exact.ContainsKey($key)) { return $exact[$key] }
    return ''
}

function Build-FinalProductName {
    param($Parts)
    $eng = @($Parts.English)
    $cn = @($Parts.Chinese)
    $cas = @($Parts.CAS)
    $selectedEnglish = @()
    for ($i = 0; $i -lt [Math]::Min(2, $eng.Count); $i++) {
        $selectedEnglish += $eng[$i]
    }
    $selectedChinese = @()
    if ($cn.Count -gt 0) {
        $cnLimit = if ($eng.Count -eq 0) { [Math]::Min(2, $cn.Count) } else { 1 }
        for ($i = 0; $i -lt $cnLimit; $i++) {
            $selectedChinese += $cn[$i]
        }
    } elseif ($selectedEnglish.Count -gt 0) {
        $tr = Get-ChineseTranslation -Name $selectedEnglish[0]
        if ($tr -ne '' -and $tr -match '[\u4e00-\u9fff]') {
            $selectedChinese += $tr
        }
    }
    $parts2 = @()
    foreach ($e in $selectedEnglish) { $parts2 += $e }
    foreach ($c in $selectedChinese) { $parts2 += $c }
    foreach ($c in $cas) { $parts2 += "CAS：$c" }
    return ($parts2 -join '；')
}

function ConvertTo-XmlText {
    param([string]$Value)
    $Value = $Value -replace '&', '&amp;'
    $Value = $Value -replace '<', '&lt;'
    $Value = $Value -replace '>', '&gt;'
    $Value = $Value -replace '"', '&quot;'
    return $Value
}

function New-WorksheetXml {
    param([string]$Brand, [string[]]$Rows, [int]$RedRow)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    $lastRow = $Rows.Count + 1
    [void]$sb.Append('<dimension ref="A1:B' + $lastRow + '"/>')
    [void]$sb.Append('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
    [void]$sb.Append('<cols><col min="1" max="1" width="14" customWidth="1"/><col min="2" max="2" width="95" customWidth="1"/></cols>')
    [void]$sb.Append('<sheetData>')
    $brandEsc = ConvertTo-XmlText -Value $Brand
    [void]$sb.Append('<row r="1"><c r="A1" t="inlineStr" s="1"><is><t xml:space="preserve">' + $brandEsc + '</t></is></c><c r="B1" t="inlineStr" s="1"><is><t xml:space="preserve">产品名称</t></is></c></row>')
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        $r = $i + 2
        $style = if ($r -eq ($RedRow + 1)) { 2 } else { 3 }
        $productEsc = ConvertTo-XmlText -Value $Rows[$i]
        $rowXml = '<row r="' + $r + '"><c r="A' + $r + '" t="inlineStr" s="' + $style + '"><is><t xml:space="preserve">' + $brandEsc + '</t></is></c><c r="B' + $r + '" t="inlineStr" s="' + $style + '"><is><t xml:space="preserve">' + $productEsc + '</t></is></c></row>'
        [void]$sb.Append($rowXml)
    }
    [void]$sb.Append('</sheetData>')
    [void]$sb.Append('<autoFilter ref="A1:B' + $lastRow + '"/>')
    [void]$sb.Append('</worksheet>')
    return $sb.ToString()
}

function New-Xlsx {
    param(
        [string]$Path,
        [string[]]$NewyanRows,
        [string[]]$KaixinRows,
        [int]$NewyanRedRow,
        [int]$KaixinRedRow
    )
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        function Add-Entry {
            param([string]$Name, [string]$Content)
            $entry = $zip.CreateEntry($Name, [System.IO.Compression.CompressionLevel]::Optimal)
            $writer = New-Object System.IO.StreamWriter($entry.Open(), (New-Object System.Text.UTF8Encoding($false)))
            $writer.Write($Content)
            $writer.Close()
        }

        $contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
            '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
            '</Types>'
        Add-Entry -Name '[Content_Types].xml' -Content $contentTypes

        $rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
            '</Relationships>'
        Add-Entry -Name '_rels/.rels' -Content $rootRels

        $workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<sheets>' +
            '<sheet name="新研博美" sheetId="1" r:id="rId1"/>' +
            '<sheet name="凯新生物" sheetId="2" r:id="rId2"/>' +
            '</sheets></workbook>'
        Add-Entry -Name 'xl/workbook.xml' -Content $workbook

        $workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>' +
            '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
            '</Relationships>'
        Add-Entry -Name 'xl/_rels/workbook.xml.rels' -Content $workbookRels

        $styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
            '<fonts count="3">' +
            '<font><sz val="11"/><name val="Calibri"/></font>' +
            '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>' +
            '<font><b/><sz val="11"/><color rgb="FFFF0000"/><name val="Calibri"/></font>' +
            '</fonts>' +
            '<fills count="3">' +
            '<fill><patternFill patternType="none"/></fill>' +
            '<fill><patternFill patternType="gray125"/></fill>' +
            '<fill><patternFill patternType="solid"><fgColor rgb="FF4472C4"/><bgColor indexed="64"/></patternFill></fill>' +
            '</fills>' +
            '<borders count="2">' +
            '<border><left/><right/><top/><bottom/><diagonal/></border>' +
            '<border><left style="thin"><color rgb="FFB7B7B7"/></left><right style="thin"><color rgb="FFB7B7B7"/></right><top style="thin"><color rgb="FFB7B7B7"/></top><bottom style="thin"><color rgb="FFB7B7B7"/></bottom><diagonal/></border>' +
            '</borders>' +
            '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
            '<cellXfs count="4">' +
            '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
            '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>' +
            '<xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>' +
            '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>' +
            '</cellXfs>' +
            '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
            '</styleSheet>'
        Add-Entry -Name 'xl/styles.xml' -Content $styles

        $sheet1 = New-WorksheetXml -Brand '新研博美' -Rows $NewyanRows -RedRow $NewyanRedRow
        $sheet2 = New-WorksheetXml -Brand '凯新生物' -Rows $KaixinRows -RedRow $KaixinRedRow
        Add-Entry -Name 'xl/worksheets/sheet1.xml' -Content $sheet1
        Add-Entry -Name 'xl/worksheets/sheet2.xml' -Content $sheet2
    } finally {
        $zip.Dispose()
        $fs.Dispose()
    }
}

function Add-DocxProgressMark {
    param(
        [string]$DocxPath,
        [int]$NewyanPara,
        [int]$KaixinPara,
        [string]$MarkerText = '【已整理至第200个，下次从第201个继续】'
    )
    $w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $backupPath = "$env:TEMP\2024年重点产品筛选_备份.docx"
    Copy-Item -LiteralPath $DocxPath -Destination $backupPath -Force
    $zip = [System.IO.Compression.ZipFile]::Open($DocxPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.GetEntry('word/document.xml')
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $xml = $reader.ReadToEnd()
        $reader.Close()
        $doc = New-Object System.Xml.XmlDocument
        $doc.LoadXml($xml)
        $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
        $ns.AddNamespace('w', $w)
        $allParas = @($doc.SelectNodes('//w:p', $ns))
        foreach ($oldP in $allParas) {
            $oldText = ''
            foreach ($t in $oldP.SelectNodes('.//w:t', $ns)) {
                $oldText += $t.InnerText
            }
            if ($oldText -like '【已整理至*') {
                [void]$oldP.ParentNode.RemoveChild($oldP)
            }
        }
        $paras = @($doc.SelectNodes('//w:p', $ns))
        foreach ($idx in @($NewyanPara, $KaixinPara)) {
            if ($idx -lt 0 -or $idx -ge $paras.Count) { continue }
            if ($idx + 1 -lt $paras.Count) {
                $nextText = ''
                foreach ($t in $paras[$idx + 1].SelectNodes('.//w:t', $ns)) {
                    $nextText += $t.InnerText
                }
                if ($nextText -like '【已整理至*') { continue }
            }
            $target = $paras[$idx]
            $newP = $doc.CreateElement('w', 'p', $w)
            $pPr = $doc.CreateElement('w', 'pPr', $w)
            [void]$newP.AppendChild($pPr)
            $run = $doc.CreateElement('w', 'r', $w)
            $rPr = $doc.CreateElement('w', 'rPr', $w)
            $b = $doc.CreateElement('w', 'b', $w)
            [void]$rPr.AppendChild($b)
            $color = $doc.CreateElement('w', 'color', $w)
            $attr = $doc.CreateAttribute('w', 'val', $w)
            $attr.Value = 'FF0000'
            [void]$color.Attributes.Append($attr)
            [void]$rPr.AppendChild($color)
            [void]$run.AppendChild($rPr)
            $t = $doc.CreateElement('w', 't', $w)
            $space = $doc.CreateAttribute('xml', 'space', 'http://www.w3.org/XML/1998/namespace')
            $space.Value = 'preserve'
            [void]$t.Attributes.Append($space)
            $t.InnerText = $MarkerText
            [void]$run.AppendChild($t)
            [void]$newP.AppendChild($run)
            [void]$target.ParentNode.InsertAfter($newP, $target)
        }
        $entry.Delete()
        $newEntry = $zip.CreateEntry('word/document.xml')
        $writer = New-Object System.IO.StreamWriter($newEntry.Open(), (New-Object System.Text.UTF8Encoding($false)))
        $writer.Write($doc.OuterXml)
        $writer.Close()
    } finally {
        $zip.Dispose()
    }
}

$newyanStart = $StartNewyan
$kaixinStart = $StartKaixin
if (-not $Overwrite -and (Test-Path -LiteralPath $ProgressPath)) {
    $prog = Get-Content -LiteralPath $ProgressPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $prog.'新研博美'.nextStart) { $newyanStart = [int]$prog.'新研博美'.nextStart }
    if ($null -ne $prog.'凯新生物'.nextStart) { $kaixinStart = [int]$prog.'凯新生物'.nextStart }
}
$newyanTarget = $newyanStart + $Limit - 1
$kaixinTarget = $kaixinStart + $Limit - 1

$paras = Get-DocxParagraphs -Path $DocxPath
$currentBrand = ''
$currentDate = ''
$cum = @{ '新研博美' = 0; '凯新生物' = 0 }
$allNewyan = New-Object System.Collections.Generic.List[object]
$allKaixin = New-Object System.Collections.Generic.List[object]

for ($i = 0; $i -lt $paras.Count; $i++) {
    $t = $paras[$i].Text.Trim()
    $brandMatch = ''
    if ($t -match '新研博美.*(重点产品|重点发布产品)') { $brandMatch = '新研博美' }
    elseif ($t -match '凯新.*(重点产品|重点发布产品)') { $brandMatch = '凯新生物' }
    if ($brandMatch -ne '') {
        $currentBrand = $brandMatch
        $currentDate = ($t -replace '^.*?[：:]\s*', '').Trim()
    } elseif ($t -ne '' -and $currentBrand -ne '') {
        $bodyNoUrl = $t -replace 'https?://\S+', ''
        $isNonProduct = $t -match '^https?://\S+$' -or ($t -match '^https?://' -and $bodyNoUrl -notmatch '[A-Za-z]')
        if ($isNonProduct) { continue }
        $cum[$currentBrand]++
        $global = $cum[$currentBrand]
        $target = if ($currentBrand -eq '新研博美') { $newyanTarget } else { $kaixinTarget }
        if ($global -gt $target) { continue }
        $parts = ConvertTo-ProductParts -Text $t
        $productName = Build-FinalProductName -Parts $parts
        $item = [pscustomobject]@{
            Global  = $global
            Date    = $currentDate
            Para    = $i
            Product = $productName
        }
        if ($currentBrand -eq '新研博美') {
            [void]$allNewyan.Add($item)
        } else {
            [void]$allKaixin.Add($item)
        }
    }
    if ($cum['新研博美'] -ge $newyanTarget -and $cum['凯新生物'] -ge $kaixinTarget) { break }
}

$newyanBatch = @($allNewyan | Where-Object { $_.Global -ge $newyanStart } | Select-Object -First $Limit)
$kaixinBatch = @($allKaixin | Where-Object { $_.Global -ge $kaixinStart } | Select-Object -First $Limit)

$newyanExisting = @()
$kaixinExisting = @()
if (-not $Overwrite -and (Test-Path -LiteralPath $StatePath)) {
    $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $newyanExisting = @($state.'新研博美')
    $kaixinExisting = @($state.'凯新生物')
}

$newyanAll = @($newyanExisting) + @($newyanBatch | ForEach-Object { $_.Product })
$kaixinAll = @($kaixinExisting) + @($kaixinBatch | ForEach-Object { $_.Product })

$stateJson = [ordered]@{
    '新研博美' = @($newyanAll)
    '凯新生物' = @($kaixinAll)
}
$stateJson | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $StatePath -Encoding UTF8

New-Xlsx -Path $XlsxPath -NewyanRows @($newyanAll) -KaixinRows @($kaixinAll) -NewyanRedRow $newyanAll.Count -KaixinRedRow $kaixinAll.Count

if ($newyanBatch.Count -gt 0 -and $kaixinBatch.Count -gt 0) {
    $newyanLastItem = $newyanBatch[-1]
    $kaixinLastItem = $kaixinBatch[-1]
    $markerText = "【已整理至 新研博美第$($newyanLastItem.Global)个、凯新生物第$($kaixinLastItem.Global)个，下次分别从第$($newyanLastItem.Global + 1)、$($kaixinLastItem.Global + 1)个继续】"
    Add-DocxProgressMark -DocxPath $DocxPath -NewyanPara $newyanLastItem.Para -KaixinPara $kaixinLastItem.Para -MarkerText $markerText
}

$progress = [ordered]@{
    updated   = (Get-Date -Format 'yyyy-MM-dd')
    source    = $DocxPath
    excel     = $XlsxPath
    state     = $StatePath
    '新研博美' = [ordered]@{
        completed = if ($newyanBatch.Count -gt 0) { $newyanBatch[-1].Global } else { $newyanStart - 1 }
        lastDate  = if ($newyanBatch.Count -gt 0) { $newyanBatch[-1].Date } else { '' }
        lastLine  = if ($newyanBatch.Count -gt 0) { $newyanBatch[-1].Product } else { '' }
        nextStart = if ($newyanBatch.Count -gt 0) { $newyanBatch[-1].Global + 1 } else { $newyanStart }
    }
    '凯新生物' = [ordered]@{
        completed = if ($kaixinBatch.Count -gt 0) { $kaixinBatch[-1].Global } else { $kaixinStart - 1 }
        lastDate  = if ($kaixinBatch.Count -gt 0) { $kaixinBatch[-1].Date } else { '' }
        lastLine  = if ($kaixinBatch.Count -gt 0) { $kaixinBatch[-1].Product } else { '' }
        nextStart = if ($kaixinBatch.Count -gt 0) { $kaixinBatch[-1].Global + 1 } else { $kaixinStart }
    }
}
$progress | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ProgressPath -Encoding UTF8

Write-Host "Excel: $XlsxPath"
Write-Host "本次新增 新研博美 $($newyanBatch.Count) 条，累计 $($newyanAll.Count) 条"
Write-Host "本次新增 凯新生物 $($kaixinBatch.Count) 条，累计 $($kaixinAll.Count) 条"
