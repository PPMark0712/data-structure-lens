class_name RangeModel
extends LabModel

var data: Array = [3, 1, 4, 1, 5, 9, 2, 6]
var bit: Array = []
var grid: Array = []
var bit2: Array = []
var table: Array = []
var result := 0

func _init(p_kind: String = "fenwick") -> void:
	super(p_kind)
	code.assign(["定位起始下标 / 幂次层", "读取或修改当前覆盖区间",
		"i += lowbit(i) 更新；i -= lowbit(i) 查询", "聚合已访问节点，返回结果"])
	recording = false
	_rebuild()
	recording = true

func operations() -> Array:
	if kind == "fenwick2":
		return [op("add", "单点增加", [field("x", "行（1–4）", "2"), field("y", "列（1–4）", "3"),
			field("value", "增量", "5")]),
			op("query", "矩形求和", [field("x1", "起始行", "1"), field("y1", "起始列", "1"),
				field("x2", "结束行", "3"), field("y2", "结束列", "4")])]
	if kind == "sparse_table":
		return [op("query", "区间最小值", [field("l", "左端点（0 起）", "1"), field("r", "右端点（含）", "6")]),
			op("build", "重新预处理", [field("values", "8 个整数", "3,1,4,1,5,9,2,6", true)])]
	return [op("add", "单点增加", [field("index", "下标（1–8）", "3"), field("value", "增量", "5")]),
		op("query", "区间求和", [field("l", "左端点（1 起）", "2"), field("r", "右端点（含）", "6")]),
		op("build", "重新构建", [field("values", "8 个整数", "3,1,4,1,5,9,2,6", true)])]

func _rebuild() -> void:
	if kind == "fenwick2":
		grid.clear()
		bit2.clear()
		for i in 5:
			var row: Array = []
			var sums: Array = []
			for j in 5:
				row.append((i + j) % 5 + 1 if i > 0 and j > 0 else 0)
				sums.append(0)
			grid.append(row)
			bit2.append(sums)
		for i in range(1, 5):
			for j in range(1, 5):
				_add2(i, j, grid[i][j])
	elif kind == "sparse_table":
		code.assign(["st[i][0] = a[i]", "st[i][k] = min(st[i][k-1], st[i+2^(k-1)][k-1])",
			"k = floor(log2(r-l+1))", "min(st[l][k], st[r-2^k+1][k])"])
		table.clear()
		for k in 4:
			var row: Array = []
			row.resize(8)
			table.append(row)
		for i in 8:
			table[0][i] = data[i]
		record("初始化长度为 1 的区间", [], 0)
		for k in range(1, 4):
			for i in range(9 - (1 << k)):
				table[k][i] = mini(table[k - 1][i], table[k - 1][i + (1 << (k - 1))])
				record("合并两个长度 %d 的区间，得到 [%d,%d]" % [1 << (k - 1), i, i + (1 << k) - 1],
					["s%d_%d" % [k, i], "s%d_%d" % [k - 1, i], "s%d_%d" % [k - 1, i + (1 << (k - 1))]], 1)
	else:
		bit.resize(9)
		bit.fill(0)
		for i in 8:
			_add1(i + 1, data[i])

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		error = ""
		var values := integers(str(args.values), 8)
		if not error.is_empty(): return false
		if values.size() != 8: return fail("请输入恰好 8 个整数。")
		begin()
		data = values
		_rebuild()
		record("预处理完成", [], 3)
		return true
	if kind == "fenwick2":
		if action == "add":
			var x := int(args.x)
			var y := int(args.y)
			if x < 1 or x > 4 or y < 1 or y > 4:
				return fail("行列下标必须在 1–4 范围内。")
			begin()
			grid[x][y] += int(args.value)
			_add2(x, y, int(args.value))
			record("更新完成", [], 3)
		else:
			var x1 := int(args.x1)
			var y1 := int(args.y1)
			var x2 := int(args.x2)
			var y2 := int(args.y2)
			if x1 < 1 or y1 < 1 or x2 > 4 or y2 > 4 or x1 > x2 or y1 > y2:
				return fail("矩形必须满足 1 ≤ 起点 ≤ 终点 ≤ 4。")
			begin()
			result = _prefix2(x2, y2) - _prefix2(x1 - 1, y2) - _prefix2(x2, y1 - 1) + _prefix2(x1 - 1, y1 - 1)
			record("容斥：S(x₂,y₂) − S(x₁−1,y₂) − S(x₂,y₁−1) + S(x₁−1,y₁−1) = %d" % result, [], 3)
		return true
	if action == "add":
		var index := int(args.index)
		if index < 1 or index > 8: return fail("下标必须在 1–8 范围内。")
		begin()
		data[index - 1] += int(args.value)
		_add1(index, int(args.value))
		record("更新完成", [], 3)
	else:
		var l := int(args.l)
		var r := int(args.r)
		var origin := 0 if kind == "sparse_table" else 1
		if l < origin or r > 7 + origin or l > r:
			return fail("区间必须满足 %d ≤ l ≤ r ≤ %d。" % [origin, 7 + origin])
		begin()
		if kind == "sparse_table":
			var k := 0
			while (1 << (k + 1)) <= r - l + 1: k += 1
			record("长度 %d，选取 k=%d；两个区间允许重叠" % [r - l + 1, k], [], 2)
			result = mini(table[k][l], table[k][r - (1 << k) + 1])
			record("区间最小值 = %d" % result, ["s%d_%d" % [k, l], "s%d_%d" % [k, r - (1 << k) + 1]], 3)
		else:
			result = _prefix1(r) - _prefix1(l - 1)
			record("prefix(%d) − prefix(%d) = %d" % [r, l - 1, result], [], 3)
	return true

func _add1(start: int, delta: int) -> void:
	var i := start
	while i <= 8:
		bit[i] += delta
		record("bit[%d] += %d；覆盖 [%d,%d]，下一站 %d" % [i, delta, i - (i & -i) + 1, i, i + (i & -i)],
			["b%d" % i], 2)
		i += i & -i

func _prefix1(start: int) -> int:
	var answer := 0
	var i := start
	calls.append("prefix(%d)" % start)
	while i > 0:
		answer += bit[i]
		record("读取 bit[%d]=%d；累计 %d；下一站 %d" % [i, bit[i], answer, i - (i & -i)], ["b%d" % i], 2)
		i -= i & -i
	calls.pop_back()
	return answer

func _add2(x: int, y: int, delta: int) -> void:
	var i := x
	while i <= 4:
		var j := y
		while j <= 4:
			bit2[i][j] += delta
			calls.assign(["外层行 i=%d，lowbit=%d" % [i, i & -i], "内层列 j=%d，lowbit=%d" % [j, j & -j]])
			record("bit[%d][%d] += %d" % [i, j, delta], ["b%d_%d" % [i, j]], 2)
			j += j & -j
		i += i & -i
	calls.clear()

func _prefix2(x: int, y: int) -> int:
	var answer := 0
	var i := x
	calls.append("prefix(%d,%d)" % [x, y])
	while i > 0:
		var j := y
		while j > 0:
			answer += bit2[i][j]
			record("读取 bit[%d][%d]=%d；累计 %d" % [i, j, bit2[i][j], answer], ["b%d_%d" % [i, j]], 2)
			j -= j & -j
		i -= i & -i
	calls.pop_back()
	return answer

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	if kind == "fenwick2":
		for i in range(1, mini(grid.size(), 5)):
			for j in range(1, 5):
				nodes.append(vertex("a%d_%d" % [i, j], grid[i][j], 60 + j * 80, 45 + i * 85,
					"a[%d,%d]" % [i, j], "box"))
				nodes.append(vertex("b%d_%d" % [i, j], bit2[i][j], 470 + j * 80, 45 + i * 85,
					"bit[%d,%d]" % [i, j], "box"))
	elif kind == "sparse_table":
		for k in table.size():
			for i in 8:
				if table[k][i] != null:
					nodes.append(vertex("s%d_%d" % [k, i], table[k][i], 60 + i * 90, 80 + k * 115,
						"[%d,%d]" % [i, i + (1 << k) - 1], "box"))
	else:
		for i in 8:
			nodes.append(vertex("a%d" % i, data[i], 60 + i * 95, 90, "a[%d]" % [i + 1], "box"))
		for i in range(1, bit.size()):
			var level := 0
			var n := i & -i
			while n > 1: level += 1; n >>= 1
			nodes.append(vertex("b%d" % i, bit[i], 60 + (i - 1) * 95, 540 - level * 95,
				"[%d,%d]" % [i - (i & -i) + 1, i]))
			var parent := i + (i & -i)
			if parent <= 8: edges.append(edge("b%d" % i, "b%d" % parent, "lowbit"))
	return {"nodes": nodes, "edges": edges, "stats":
		"4×4  ·  左：原始矩阵  /  右：树状数组" if kind == "fenwick2" else
		("n=8  ·  静态 RMQ  ·  每层长度 2^k" if kind == "sparse_table" else "n=8  ·  1-based  ·  lowbit(i) = i & −i")}

func invariant() -> String:
	if kind == "fenwick":
		for i in range(1, 9):
			var expected := 0
			for j in range(i - (i & -i), i): expected += data[j]
			if bit[i] != expected: return "Fenwick coverage mismatch"
	if kind == "fenwick2":
		for i in range(1, 5):
			for j in range(1, 5):
				var expected := 0
				for x in range(i - (i & -i) + 1, i + 1):
					for y in range(j - (j & -j) + 1, j + 1): expected += grid[x][y]
				if bit2[i][j] != expected: return "2D Fenwick coverage mismatch"
	if kind == "sparse_table":
		for k in table.size():
			for i in range(9 - (1 << k)):
				var expected: int = data[i]
				for j in range(i, i + (1 << k)): expected = mini(expected, data[j])
				if table[k][i] != expected: return "ST interval minimum mismatch"
	return ""
