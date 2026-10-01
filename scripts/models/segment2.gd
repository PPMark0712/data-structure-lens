class_name Segment2Model
extends LabModel

var grid: Array = []
var sums: Array = []
var intervals: Dictionary = {}
var focus_x := 1
var result := 0

func _init(p_kind: String = "segment2") -> void:
	super(p_kind)
	code.assign(["外层树定位行区间", "在完全覆盖的行节点中进入列树",
		"内层树定位列区间 / 单点", "回溯：合并子节点之和"])
	for i in 4:
		var row: Array = []
		for j in 4: row.append((i + j) % 5 + 1)
		grid.append(row)
	for i in 16:
		var row: Array = []
		row.resize(16)
		row.fill(0)
		sums.append(row)
	_ranges(1, 1, 4)
	_build_x(1, 1, 4)

func operations() -> Array:
	return [op("add", "单点增加", [field("x", "行（1–4）", "1"), field("y", "列（1–4）", "2"),
		field("value", "增量", "5")]),
		op("query", "矩形求和", [field("x1", "起始行", "1"), field("y1", "起始列", "2"),
			field("x2", "结束行", "3"), field("y2", "结束列", "4")]),
		op("inspect", "展开节点的列树", [field("node", "行树节点编号（1–7）", "1")])]

func _ranges(v: int, l: int, r: int) -> void:
	intervals[v] = [l, r]
	if l < r:
		var mid := (l + r) >> 1
		_ranges(v * 2, l, mid)
		_ranges(v * 2 + 1, mid + 1, r)

func _build_x(v: int, l: int, r: int) -> void:
	if l < r:
		var mid := (l + r) >> 1
		_build_x(v * 2, l, mid)
		_build_x(v * 2 + 1, mid + 1, r)
	_build_y(v, l, r, 1, 1, 4)

func _build_y(vx: int, lx: int, rx: int, vy: int, ly: int, ry: int) -> void:
	if ly == ry:
		sums[vx][vy] = grid[lx - 1][ly - 1] if lx == rx else sums[vx * 2][vy] + sums[vx * 2 + 1][vy]
	else:
		var mid := (ly + ry) >> 1
		_build_y(vx, lx, rx, vy * 2, ly, mid)
		_build_y(vx, lx, rx, vy * 2 + 1, mid + 1, ry)
		sums[vx][vy] = sums[vx][vy * 2] + sums[vx][vy * 2 + 1]

func perform(action: String, args: Dictionary) -> bool:
	if action == "inspect":
		var node := int(args.node)
		if not intervals.has(node): return fail("行树节点编号为 1–7。")
		begin()
		focus_x = node
		record("展开行节点 #%d 对应的列线段树" % node, ["x%d" % node], 1)
		return true
	if action == "add":
		var x := int(args.x)
		var y := int(args.y)
		if x < 1 or x > 4 or y < 1 or y > 4:
			return fail("行列下标必须在 1–4 范围内。")
		begin()
		grid[x - 1][y - 1] += int(args.value)
		_update_x(1, 1, 4, x, y)
		record("单点更新完成，矩阵总和 = %d" % sums[1][1], ["x1"], 3)
	else:
		var x1 := int(args.x1)
		var y1 := int(args.y1)
		var x2 := int(args.x2)
		var y2 := int(args.y2)
		if x1 < 1 or y1 < 1 or x2 > 4 or y2 > 4 or x1 > x2 or y1 > y2:
			return fail("矩形必须满足 1 ≤ 起点 ≤ 终点 ≤ 4。")
		begin()
		result = _query_x(1, 1, 4, x1, x2, y1, y2)
		record("矩形求和结果 = %d" % result, [], 3)
	return true

func _update_x(v: int, l: int, r: int, x: int, y: int) -> void:
	calls.append("行树 #%d [%d,%d]" % [v, l, r])
	focus_x = v
	record("进入行区间 [%d,%d]" % [l, r], ["x%d" % v], 0)
	if l < r:
		var mid := (l + r) >> 1
		if x <= mid: _update_x(v * 2, l, mid, x, y)
		else: _update_x(v * 2 + 1, mid + 1, r, x, y)
	focus_x = v
	_update_y(v, l, r, 1, 1, 4, y)
	calls.pop_back()

func _update_y(vx: int, lx: int, rx: int, vy: int, ly: int, ry: int, y: int) -> void:
	calls.append("列树 [%d,%d]" % [ly, ry])
	record("更新行节点 #%d 的列区间 [%d,%d]" % [vx, ly, ry], ["y%d_%d" % [vx, vy]], 2)
	if ly == ry:
		sums[vx][vy] = grid[lx - 1][ly - 1] if lx == rx else sums[vx * 2][vy] + sums[vx * 2 + 1][vy]
	else:
		var mid := (ly + ry) >> 1
		if y <= mid: _update_y(vx, lx, rx, vy * 2, ly, mid, y)
		else: _update_y(vx, lx, rx, vy * 2 + 1, mid + 1, ry, y)
		sums[vx][vy] = sums[vx][vy * 2] + sums[vx][vy * 2 + 1]
	record("回溯列节点：sum=%d" % sums[vx][vy], ["y%d_%d" % [vx, vy]], 3)
	calls.pop_back()

func _query_x(v: int, l: int, r: int, x1: int, x2: int, y1: int, y2: int) -> int:
	if x2 < l or x1 > r: return 0
	calls.append("查行 [%d,%d]" % [l, r])
	focus_x = v
	record("访问行区间 [%d,%d]" % [l, r], ["x%d" % v], 0)
	var answer := 0
	if x1 <= l and r <= x2:
		answer = _query_y(v, 1, 1, 4, y1, y2)
	else:
		var mid := (l + r) >> 1
		answer = _query_x(v * 2, l, mid, x1, x2, y1, y2) + _query_x(v * 2 + 1, mid + 1, r, x1, x2, y1, y2)
	calls.pop_back()
	return answer

func _query_y(vx: int, vy: int, l: int, r: int, y1: int, y2: int) -> int:
	if y2 < l or y1 > r: return 0
	calls.append("查列 [%d,%d]" % [l, r])
	record("查询列区间 [%d,%d]" % [l, r], ["y%d_%d" % [vx, vy]], 2)
	var answer := 0
	if y1 <= l and r <= y2:
		answer = sums[vx][vy]
		record("矩形块完全覆盖，返回 %d" % answer, ["y%d_%d" % [vx, vy]], 3)
	else:
		var mid := (l + r) >> 1
		answer = _query_y(vx, vy * 2, l, mid, y1, y2) + _query_y(vx, vy * 2 + 1, mid + 1, r, y1, y2)
	calls.pop_back()
	return answer

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	for v in intervals:
		var l: int = intervals[v][0]
		var r: int = intervals[v][1]
		var depth := 0 if v == 1 else (1 if v < 4 else 2)
		var x := 80 + (l + r - 2) * 60
		nodes.append(vertex("x%d" % v, sums[v][1], x, 70 + depth * 100,
			"#%d 行[%d,%d]" % [v, l, r], "circle", "green" if v == focus_x else ""))
		nodes.append(vertex("y%d_%d" % [focus_x, v], sums[focus_x][v], x + 540, 70 + depth * 100,
			"列[%d,%d]" % [l, r]))
		if v > 1:
			edges.append(edge("x%d" % (v >> 1), "x%d" % v))
			edges.append(edge("y%d_%d" % [focus_x, v >> 1], "y%d_%d" % [focus_x, v]))
	for i in 4:
		for j in 4:
			nodes.append(vertex("a%d_%d" % [i + 1, j + 1], grid[i][j], 120 + j * 85, 400 + i * 80,
				"[%d,%d]" % [i + 1, j + 1], "box"))
	return {"nodes": nodes, "edges": edges,
		"stats": "4×4  ·  左：行树  /  右：行节点 #%d 的列树" % focus_x}

func invariant() -> String:
	for vx in intervals:
		for vy in intervals:
			var expected := 0
			for x in range(intervals[vx][0], intervals[vx][1] + 1):
				for y in range(intervals[vy][0], intervals[vy][1] + 1): expected += grid[x - 1][y - 1]
			if sums[vx][vy] != expected: return "2D segment rectangle mismatch"
	return ""
