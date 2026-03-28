"""
Excel 시각 작업 모듈 — win32com
Claude가 Excel을 직접 조작하는 모습이 화면에 그대로 나옴.
셀 이동, 타이핑, 수식, 피벗, 차트 — 전부 실제 UI에서 보임.
"""

import time
import win32com.client as win32

DELAY = 0.08  # 타이핑 딜레이 (초) — 사람처럼 보이는 속도


def _open_excel():
    """Excel 열기 (이미 열려있으면 재사용)"""
    try:
        xl = win32.GetActiveObject("Excel.Application")
    except:
        xl = win32.Dispatch("Excel.Application")

    xl.Visible = True
    xl.DisplayAlerts = False
    xl.ScreenUpdating = True
    return xl


def _type_cell(ws, row, col, value, delay=DELAY):
    """셀 선택 후 타이핑 — 커서 이동이 화면에 보임"""
    cell = ws.Cells(row, col)
    cell.Select()
    time.sleep(delay)
    cell.Value = value
    time.sleep(delay * 0.5)


def _header_style(cell, color=0x1F4E79):
    """헤더 스타일 — 파란 배경, 흰 글씨, 굵게"""
    cell.Interior.Color = color
    cell.Font.Color = 0xFFFFFF
    cell.Font.Bold = True


# ═══════════════════════════════════════════════════════════════
# Task 1: 매출 데이터 입력 + 피벗 테이블
# ═══════════════════════════════════════════════════════════════

def task_pivot_demo():
    """
    매출 데이터를 셀에 직접 타이핑하고 피벗 테이블 만들기.
    전 과정이 Excel UI에서 실시간으로 보임.
    """
    xl = _open_excel()
    wb = xl.Workbooks.Add()
    ws = wb.Worksheets(1)
    ws.Name = "매출데이터"
    xl.ActiveWindow.WindowState = -4137  # xlMaximized

    # ── 헤더 입력 ─────────────────────────────────────────────
    headers = ["날짜", "제품", "카테고리", "담당자", "수량", "단가", "매출액"]
    for i, h in enumerate(headers, 1):
        _type_cell(ws, 1, i, h)
        _header_style(ws.Cells(1, i))

    time.sleep(0.3)

    # ── 데이터 입력 ────────────────────────────────────────────
    rows = [
        ("2024-01-05", "노트북",   "전자",  "김민준", 3, 1200000, "=F2*G2"),
        ("2024-01-08", "마우스",   "전자",  "이서연", 15, 35000,  "=F3*G3"),
        ("2024-01-12", "책상",     "가구",  "박지호", 2, 450000,  "=F4*G4"),
        ("2024-01-15", "모니터",   "전자",  "김민준", 5, 380000,  "=F5*G5"),
        ("2024-01-18", "의자",     "가구",  "이서연", 4, 280000,  "=F6*G6"),
        ("2024-01-22", "키보드",   "전자",  "최현우", 20, 85000,  "=F7*G7"),
        ("2024-01-25", "책상",     "가구",  "박지호", 1, 450000,  "=F8*G8"),
        ("2024-02-03", "노트북",   "전자",  "최현우", 2, 1200000, "=F9*G9"),
        ("2024-02-07", "마우스",   "전자",  "이서연", 30, 35000,  "=F10*G10"),
        ("2024-02-11", "모니터",   "전자",  "김민준", 3, 380000,  "=F11*G11"),
        ("2024-02-14", "의자",     "가구",  "최현우", 6, 280000,  "=F12*G12"),
        ("2024-02-20", "키보드",   "전자",  "박지호", 25, 85000,  "=F13*G13"),
    ]

    for r, row_data in enumerate(rows, 2):
        for c, val in enumerate(row_data, 1):
            _type_cell(ws, r, c, val, DELAY * 0.6)
        time.sleep(0.1)

    # ── 열 너비 자동 조정 ─────────────────────────────────────
    ws.Columns("A:G").AutoFit()
    time.sleep(0.4)

    # ── 테이블 스타일 적용 ────────────────────────────────────
    tbl_range = ws.Range("A1:G13")
    tbl_range.Select()
    time.sleep(0.3)
    wb.ActiveSheet.ListObjects.Add(1, tbl_range, None, 1)
    time.sleep(0.5)

    # ── 피벗 시트 추가 ────────────────────────────────────────
    ws_pivot = wb.Worksheets.Add()
    ws_pivot.Name = "피벗분석"
    time.sleep(0.3)

    # ── 피벗 테이블 생성 ─────────────────────────────────────
    src_range = wb.Worksheets("매출데이터").Range("A1:G13")
    pc = wb.PivotCaches().Create(
        SourceType=1,  # xlDatabase
        SourceData=src_range,
    )
    pt = pc.CreatePivotTable(
        TableDestination=ws_pivot.Range("B2"),
        TableName="매출피벗",
    )
    time.sleep(0.5)

    # ── 피벗 필드 설정 ────────────────────────────────────────
    # 행: 카테고리, 담당자
    pt.PivotFields("카테고리").Orientation = 1   # xlRowField
    pt.PivotFields("카테고리").Position = 1
    pt.PivotFields("담당자").Orientation = 1
    pt.PivotFields("담당자").Position = 2
    time.sleep(0.3)

    # 값: 매출액 합계, 수량 합계
    pf_sales = pt.PivotFields("매출액")
    pf_sales.Orientation = 4  # xlDataField
    pf_sales.Function = -4157  # xlSum
    pf_sales.NumberFormat = "#,##0"
    time.sleep(0.2)

    pf_qty = pt.PivotFields("수량")
    pf_qty.Orientation = 4
    pf_qty.Function = -4157
    time.sleep(0.3)

    # 피벗 스타일
    pt.TableStyle2 = "PivotStyleMedium9"
    ws_pivot.Columns("A:F").AutoFit()
    ws_pivot.Activate()
    ws_pivot.Range("B2").Select()

    time.sleep(0.5)
    return {"ok": True, "task": "pivot_demo", "sheets": ["매출데이터", "피벗분석"]}


# ═══════════════════════════════════════════════════════════════
# Task 2: 차트 생성
# ═══════════════════════════════════════════════════════════════

def task_chart_demo():
    """
    월별 매출 데이터로 막대+꺾은선 혼합 차트 생성.
    차트가 만들어지는 과정이 화면에 보임.
    """
    xl = _open_excel()
    wb = xl.Workbooks.Add()
    ws = wb.Worksheets(1)
    ws.Name = "월별매출"
    xl.ActiveWindow.WindowState = -4137

    # 데이터 입력
    headers = ["월", "전자", "가구", "합계"]
    for i, h in enumerate(headers, 1):
        _type_cell(ws, 1, i, h)
        _header_style(ws.Cells(1, i), 0x203864)

    data = [
        ("1월",  3610000, 900000,  "=B2+C2"),
        ("2월",  4255000, 1680000, "=B3+C3"),
        ("3월",  2890000, 450000,  "=B4+C4"),
        ("4월",  5120000, 1350000, "=B5+C5"),
        ("5월",  3780000, 2100000, "=B6+C6"),
        ("6월",  6430000, 900000,  "=B7+C7"),
    ]

    for r, row in enumerate(data, 2):
        for c, val in enumerate(row, 1):
            _type_cell(ws, r, c, val)
        time.sleep(0.15)

    ws.Columns("A:D").AutoFit()
    time.sleep(0.4)

    # 데이터 선택 후 차트 삽입
    ws.Range("A1:C7").Select()
    time.sleep(0.4)

    chart_obj = ws.ChartObjects().Add(Left=20, Top=160, Width=480, Height=280)
    chart = chart_obj.Chart
    chart.ChartType = 57  # xlColumnClustered
    time.sleep(0.4)

    # 차트 스타일
    chart.ChartStyle = 227
    chart.HasTitle = True
    chart.ChartTitle.Text = "월별 카테고리별 매출"
    chart.ChartTitle.Font.Size = 14
    chart.ChartTitle.Font.Bold = True
    time.sleep(0.3)

    # 합계를 꺾은선으로
    ws.Range("A1:A7,D1:D7").Select()
    series = chart.SeriesCollection().NewSeries()
    series.XValues = ws.Range("A2:A7")
    series.Values = ws.Range("D2:D7")
    series.Name = "합계"
    series.ChartType = 4   # xlLine
    series.AxisGroup = 2   # 보조축
    time.sleep(0.5)

    ws.Range("A1").Select()
    return {"ok": True, "task": "chart_demo", "sheets": ["월별매출"]}


# ═══════════════════════════════════════════════════════════════
# Task 3: 수식 + 조건부 서식
# ═══════════════════════════════════════════════════════════════

def task_formula_demo():
    """
    수식 입력 + 조건부 서식 적용.
    셀마다 수식이 타이핑되고, 색이 입혀지는 게 보임.
    """
    xl = _open_excel()
    wb = xl.Workbooks.Add()
    ws = wb.Worksheets(1)
    ws.Name = "성과분석"
    xl.ActiveWindow.WindowState = -4137

    headers = ["담당자", "목표", "실적", "달성률", "등급"]
    colors = [0x1F4E79, 0x1F4E79, 0x1F4E79, 0x1F4E79, 0x1F4E79]
    for i, h in enumerate(headers, 1):
        _type_cell(ws, 1, i, h)
        _header_style(ws.Cells(1, i))

    people = [
        ("김민준", 5000000, 5800000),
        ("이서연", 4500000, 4200000),
        ("박지호", 6000000, 6750000),
        ("최현우", 5500000, 5500000),
        ("정예린", 4000000, 3600000),
    ]

    for r, (name, target, actual) in enumerate(people, 2):
        _type_cell(ws, r, 1, name)
        _type_cell(ws, r, 2, target)
        _type_cell(ws, r, 3, actual)
        # 달성률 수식
        _type_cell(ws, r, 4, f"=C{r}/B{r}")
        ws.Cells(r, 4).NumberFormat = "0.0%"
        # 등급 수식
        _type_cell(ws, r, 5, f'=IF(D{r}>=1.1,"S",IF(D{r}>=1,"A",IF(D{r}>=0.9,"B","C")))')
        time.sleep(0.2)

    ws.Columns("A:E").AutoFit()
    time.sleep(0.4)

    # 조건부 서식 — 달성률 컬러스케일
    rng = ws.Range("D2:D6")
    rng.Select()
    time.sleep(0.3)
    cf = rng.FormatConditions.AddColorScale(ColorScaleType=3)
    cf.ColorScaleCriteria(1).FormatColor.Color = 0x0000FF  # 빨강 (낮음)
    cf.ColorScaleCriteria(2).FormatColor.Color = 0x00FFFF  # 노랑 (중간)
    cf.ColorScaleCriteria(3).FormatColor.Color = 0x00FF00  # 초록 (높음)
    time.sleep(0.5)

    ws.Range("A1").Select()
    return {"ok": True, "task": "formula_demo", "sheets": ["성과분석"]}


# ═══════════════════════════════════════════════════════════════
# 디스패처
# ═══════════════════════════════════════════════════════════════

TASKS = {
    "pivot_demo":   task_pivot_demo,
    "chart_demo":   task_chart_demo,
    "formula_demo": task_formula_demo,
}

def run_task(task_id):
    fn = TASKS.get(task_id)
    if not fn:
        return {"ok": False, "error": f"Unknown task: {task_id}"}
    try:
        return fn()
    except Exception as e:
        return {"ok": False, "error": str(e)}
