class_name DisjointSetModel
extends LabModel

const MAX_SIZE := 12
const HORIZONTAL_GAP := 112.0
const ROOT_GAP := 56.0

var count := 10
var parent: Array[int] = []
var rank: Array[int] = []
var size: Array[int] = []
var weight: Array[int] = []
var merge_history: Array[Dictionary] = []
var path_compression := true
var union_strategy := "none"
var result := 0
var connected_result := false
var has_result := false
var outcome := ""

func _init(p_kind: String = "disjoint_set") -> void:
	super(p_kind)
	match kind:
		"weighted_disjoint_set":
			code.assign([
				"find(x)：递归到根；回溯时 weight[x] += weight[fa[x]]",
				"约束：value[b] - value[a] = delta",
				"合并：按 size 连接两棵树，并设置根之间的差值",
				"查询：weight[b] - weight[a]"
			])
			_reset(8)
			parent[1] = 2
			weight[1] = -3
			parent[2] = 3
			weight[2] = 2
			parent[4] = 5
			weight[4] = -4
			parent[6] = 7
			weight[6] = 2
			_rebuild_metadata()
		"rollback_disjoint_set":
			code.assign([
				"find(x)：沿 fa 向上，不做路径压缩",
				"合并：按 size 将小树挂到大树",
				"记录：(子根, 父根, 父根原 size)",
				"撤销：弹出记录并恢复 parent 与 size"
			])
			_reset(8)
			_merge_rollback_raw(1, 2)
			_merge_rollback_raw(3, 4)
			_merge_rollback_raw(1, 3)
			_merge_rollback_raw(5, 6)
		_:
			code.assign([
				"find(x)：沿 fa 递归找到代表元",
				"路径压缩开启时：fa[x] = find(fa[x])",
				"合并：不开启 / 按 rank / 按 size",
				"初始化：fa[i] = i"
			])
			_reset(10)
			parent[1] = 2
			parent[2] = 3
			parent[4] = 5
			parent[5] = 6
			parent[7] = 8
			parent[9] = 10
			_rebuild_metadata()

func _standard_settings() -> Array:
	return [
		toggle_field("path_compression", "路径压缩", path_compression),
		options_field("union_strategy", "合并策略", union_strategy, [
			{"label": "不开启", "value": "none"},
			{"label": "按 rank", "value": "rank"},
			{"label": "按 size", "value": "size"}
		])
	]

func operations() -> Array:
	match kind:
		"weighted_disjoint_set":
			return [
				op("relation", "添加差值约束", [
					field("a", "元素 a（1–%d）" % count, "1"),
					field("b", "元素 b（1–%d）" % count, "4"),
					field("delta", "value[b] - value[a]", "7")
				]),
				op("query", "查询两点差值", [
					field("a", "元素 a（1–%d）" % count, "1"),
					field("b", "元素 b（1–%d）" % count, "3")
				]),
				op("potential", "查询到根差值", [
					field("x", "元素 x（1–%d）" % count, "1")
				]),
				op("build", "重新初始化", [field("size", "元素个数（1–12）", "8")])
			]
		"rollback_disjoint_set":
			return [
				op("union", "合并集合", [
					field("a", "元素 a（1–%d）" % count, "7"),
					field("b", "元素 b（1–%d）" % count, "8")
				]),
				op("connected", "判断连通", [
					field("a", "元素 a（1–%d）" % count, "2"),
					field("b", "元素 b（1–%d）" % count, "4")
				]),
				op("rollback", "撤销最近合并", [
					field("steps", "撤销次数（1–%d）" % merge_history.size(), "1")
				]),
				op("build", "重新初始化", [field("size", "元素个数（1–12）", "8")])
			]
		_:
			var settings := _standard_settings()
			return [
				op("find", "查找代表元", settings + [
					field("x", "元素 x（1–%d）" % count, "1")
				]),
				op("union", "合并集合", settings + [
					field("a", "元素 a（1–%d）" % count, "1"),
					field("b", "元素 b（1–%d）" % count, "5")
				]),
				op("connected", "判断连通", settings + [
					field("a", "元素 a（1–%d）" % count, "1"),
					field("b", "元素 b（1–%d）" % count, "7")
				]),
				op("build", "重新初始化", settings + [
					field("size", "元素个数（1–12）", "10")
				])
			]

func _reset(new_count: int) -> void:
	count = new_count
	parent.clear()
	rank.clear()
	size.clear()
	weight.clear()
	for i in range(count + 1):
		parent.append(i)
		rank.append(0)
		size.append(0 if i == 0 else 1)
		weight.append(0)
	merge_history.clear()
	result = 0
	connected_result = false
	has_result = false
	outcome = ""

func _valid_element(value: int) -> bool:
	return value >= 1 and value <= count

func _root_without_changes(x: int) -> int:
	while parent[x] != x:
		x = parent[x]
	return x

func _rebuild_metadata() -> void:
	for i in range(count + 1):
		rank[i] = 0
		size[i] = 0
	for i in range(1, count + 1):
		var current := i
		var depth := 0
		while parent[current] != current:
			current = parent[current]
			depth += 1
		size[current] += 1
		rank[current] = maxi(rank[current], depth)

func _find_standard(x: int) -> int:
	calls.append("find(%d)" % x)
	record("检查 %d 是否为根：fa[%d] = %d" % [x, x, parent[x]], ["d%d" % x], 0)
	if x == parent[x]:
		record("%d == fa[%d]，返回代表元 %d" % [x, x, x], ["d%d" % x], 0)
		calls.pop_back()
		return x
	var old_parent := parent[x]
	record("%d 不是根，递归执行 find(%d)" % [x, old_parent],
		["d%d" % x, "d%d" % old_parent], 0)
	var root := _find_standard(old_parent)
	if path_compression:
		if parent[x] != root:
			parent[x] = root
			record("递归回溯：fa[%d] = %d，压缩一层路径" % [x, root],
				["d%d" % x, "d%d" % root], 1)
		else:
			record("递归回溯：fa[%d] 已直接指向根 %d" % [x, root],
				["d%d" % x, "d%d" % root], 1)
	else:
		record("递归回溯：路径压缩关闭，保留 fa[%d] = %d" % [x, parent[x]],
			["d%d" % x, "d%d" % parent[x]], 0)
	calls.pop_back()
	return root

func _attach_standard(root_a: int, root_b: int) -> Array[int]:
	var child := root_a
	var target := root_b
	if union_strategy == "rank":
		if rank[root_a] > rank[root_b]:
			child = root_b
			target = root_a
	elif union_strategy == "size":
		if size[root_a] > size[root_b]:
			child = root_b
			target = root_a
	parent[child] = target
	size[target] += size[child]
	size[child] = 0
	if rank[child] >= rank[target]:
		rank[target] = rank[child] + 1
	return [child, target]

func _perform_standard(action: String, args: Dictionary) -> bool:
	var strategy := str(args.get("union_strategy", union_strategy))
	if strategy not in ["none", "rank", "size"]:
		return fail("合并策略无效。")
	var compress := bool(args.get("path_compression", path_compression))
	if action == "build":
		var new_count := int(args.get("size", 0))
		if new_count < 1 or new_count > MAX_SIZE:
			return fail("元素个数必须在 1 到 %d 之间。" % MAX_SIZE)
		path_compression = compress
		union_strategy = strategy
		begin()
		_reset(new_count)
		record("令每个 fa[i] = i，得到 %d 个单元素集合" % count,
			range(1, count + 1).map(func(i): return "d%d" % i), 3)
		return true
	var a := int(args.get("a", args.get("x", 0)))
	var b := int(args.get("b", 0))
	if not _valid_element(a):
		return fail("元素必须在 1 到 %d 之间。" % count)
	if action in ["union", "connected"] and not _valid_element(b):
		return fail("元素 b 必须在 1 到 %d 之间。" % count)
	path_compression = compress
	union_strategy = strategy
	outcome = ""
	begin()
	match action:
		"find":
			result = _find_standard(a)
			outcome = "find(%d) = %d" % [a, result]
			record("查找完成：%d 的代表元是 %d" % [a, result],
				["d%d" % a, "d%d" % result], 0)
		"union":
			var root_a := _find_standard(a)
			var root_b := _find_standard(b)
			if root_a == root_b:
				outcome = "%d 与 %d 已属于同一集合" % [a, b]
				record(outcome, ["d%d" % root_a], 2)
			else:
				var joined := _attach_standard(root_a, root_b)
				outcome = "fa[%d] = %d" % [joined[0], joined[1]]
				var strategy_text: String = {
					"none": "未启用合并启发式",
					"rank": "按 rank 合并",
					"size": "按 size 合并"
				}[union_strategy]
				record("合并：令 fa[%d] = %d；%s" %
					[joined[0], joined[1], strategy_text],
					["d%d" % joined[0], "d%d" % joined[1]], 2)
		"connected":
			var root_a := _find_standard(a)
			var root_b := _find_standard(b)
			connected_result = root_a == root_b
			outcome = "%d 与 %d%s连通" % [a, b, "" if connected_result else "不"]
			record("%s：代表元分别为 %d 与 %d" % [outcome, root_a, root_b],
				["d%d" % root_a, "d%d" % root_b], 0)
		_:
			return fail("未知操作。")
	return true

func _peek_weighted(x: int) -> Array[int]:
	var total := 0
	while parent[x] != x:
		total += weight[x]
		x = parent[x]
	return [x, total]

func _find_weighted(x: int) -> int:
	calls.append("find(%d)" % x)
	record("检查 %d：fa[%d] = %d，边权 = %d" % [x, x, parent[x], weight[x]],
		["d%d" % x], 0)
	if parent[x] == x:
		record("%d 是根，到根差值为 0" % x, ["d%d" % x], 0)
		calls.pop_back()
		return x
	var old_parent := parent[x]
	var old_weight := weight[x]
	var root := _find_weighted(old_parent)
	var total_weight := old_weight + weight[old_parent]
	if parent[x] != root or weight[x] != total_weight:
		parent[x] = root
		weight[x] = total_weight
		record("回溯：fa[%d] = %d，weight[%d] = %d" % [x, root, x, total_weight],
			["d%d" % x, "d%d" % root], 0)
	else:
		record("%d 已直接连接根 %d，到根差值为 %d" % [x, root, total_weight],
			["d%d" % x, "d%d" % root], 0)
	calls.pop_back()
	return root

func _perform_weighted(action: String, args: Dictionary) -> bool:
	if action == "build":
		var new_count := int(args.get("size", 0))
		if new_count < 1 or new_count > MAX_SIZE:
			return fail("元素个数必须在 1 到 %d 之间。" % MAX_SIZE)
		begin()
		_reset(new_count)
		record("初始化 %d 个集合；根节点到自身的差值均为 0" % count,
			range(1, count + 1).map(func(i): return "d%d" % i), 0)
		return true
	var a := int(args.get("a", args.get("x", 0)))
	var b := int(args.get("b", 0))
	if not _valid_element(a):
		return fail("元素必须在 1 到 %d 之间。" % count)
	if action in ["relation", "query"] and not _valid_element(b):
		return fail("元素 b 必须在 1 到 %d 之间。" % count)
	var delta := int(args.get("delta", 0))
	if action == "relation":
		var before_a := _peek_weighted(a)
		var before_b := _peek_weighted(b)
		if before_a[0] == before_b[0] and before_b[1] - before_a[1] != delta:
			return fail("该约束与已有差值矛盾。")
	outcome = ""
	has_result = false
	begin()
	match action:
		"relation":
			var root_a := _find_weighted(a)
			var root_b := _find_weighted(b)
			if root_a == root_b:
				outcome = "约束与已有关系一致"
				record("%d 与 %d 已连通，差值 %d 一致" % [a, b, delta],
					["d%d" % a, "d%d" % b], 1)
			else:
				var potential_a := weight[a]
				var potential_b := weight[b]
				if size[root_a] < size[root_b]:
					parent[root_a] = root_b
					weight[root_a] = potential_b - potential_a - delta
					size[root_b] += size[root_a]
					size[root_a] = 0
					record("按 size 合并：fa[%d] = %d，根间差值 = %d" %
						[root_a, root_b, weight[root_a]],
						["d%d" % root_a, "d%d" % root_b], 2)
				else:
					parent[root_b] = root_a
					weight[root_b] = delta + potential_a - potential_b
					size[root_a] += size[root_b]
					size[root_b] = 0
					record("按 size 合并：fa[%d] = %d，根间差值 = %d" %
						[root_b, root_a, weight[root_b]],
						["d%d" % root_a, "d%d" % root_b], 2)
				outcome = "value[%d] - value[%d] = %d" % [b, a, delta]
		"query":
			var root_a := _find_weighted(a)
			var root_b := _find_weighted(b)
			if root_a != root_b:
				outcome = "%d 与 %d 尚未建立关系" % [a, b]
				record(outcome, ["d%d" % a, "d%d" % b], 3)
			else:
				result = weight[b] - weight[a]
				has_result = true
				outcome = "value[%d] - value[%d] = %d" % [b, a, result]
				record("两点到同一根的差值相减：%d - %d = %d" %
					[weight[b], weight[a], result], ["d%d" % a, "d%d" % b], 3)
		"potential":
			var root := _find_weighted(a)
			result = weight[a]
			has_result = true
			outcome = "value[%d] - value[%d] = %d" % [a, root, result]
			record("元素 %d 到根 %d 的累计差值为 %d" % [a, root, result],
				["d%d" % a, "d%d" % root], 0)
		_:
			return fail("未知操作。")
	return true

func _find_rollback(x: int) -> int:
	calls.append("find(%d)" % x)
	record("访问 %d：fa[%d] = %d；可撤销结构不压缩路径" %
		[x, x, parent[x]], ["d%d" % x], 0)
	if parent[x] == x:
		calls.pop_back()
		return x
	var root := _find_rollback(parent[x])
	calls.pop_back()
	return root

func _merge_rollback_raw(a: int, b: int) -> void:
	var root_a := _root_without_changes(a)
	var root_b := _root_without_changes(b)
	if root_a == root_b:
		merge_history.append({"merged": false})
		return
	if size[root_a] < size[root_b]:
		var temporary := root_a
		root_a = root_b
		root_b = temporary
	merge_history.append({
		"merged": true,
		"child": root_b,
		"target": root_a,
		"target_size": size[root_a]
	})
	parent[root_b] = root_a
	size[root_a] += size[root_b]

func _perform_rollback(action: String, args: Dictionary) -> bool:
	if action == "build":
		var new_count := int(args.get("size", 0))
		if new_count < 1 or new_count > MAX_SIZE:
			return fail("元素个数必须在 1 到 %d 之间。" % MAX_SIZE)
		begin()
		_reset(new_count)
		record("初始化 %d 个单元素集合，历史栈为空" % count,
			range(1, count + 1).map(func(i): return "d%d" % i), 0)
		return true
	if action == "rollback":
		var steps := int(args.get("steps", 0))
		if steps < 1 or steps > merge_history.size():
			return fail("撤销次数必须在 1 到 %d 之间。" % merge_history.size())
		outcome = ""
		begin()
		for i in steps:
			var change: Dictionary = merge_history.pop_back()
			if not change.merged:
				record("弹出一次未改变结构的重复合并记录", [], 3)
				continue
			parent[change.child] = change.child
			size[change.target] = change.target_size
			record("撤销：恢复 fa[%d] = %d，size[%d] = %d" %
				[change.child, change.child, change.target, change.target_size],
				["d%d" % change.child, "d%d" % change.target], 3)
		outcome = "已撤销 %d 次合并" % steps
		return true
	var a := int(args.get("a", 0))
	var b := int(args.get("b", 0))
	if not _valid_element(a) or not _valid_element(b):
		return fail("元素必须在 1 到 %d 之间。" % count)
	outcome = ""
	begin()
	match action:
		"union":
			var root_a := _find_rollback(a)
			var root_b := _find_rollback(b)
			if root_a == root_b:
				merge_history.append({"merged": false})
				outcome = "%d 与 %d 已属于同一集合" % [a, b]
				record(outcome + "；压入空变更记录", ["d%d" % root_a], 2)
			else:
				if size[root_a] < size[root_b]:
					var temporary := root_a
					root_a = root_b
					root_b = temporary
				merge_history.append({
					"merged": true,
					"child": root_b,
					"target": root_a,
					"target_size": size[root_a]
				})
				parent[root_b] = root_a
				size[root_a] += size[root_b]
				outcome = "fa[%d] = %d" % [root_b, root_a]
				record("按 size 合并并压栈：fa[%d] = %d，size[%d] = %d" %
					[root_b, root_a, root_a, size[root_a]],
					["d%d" % root_a, "d%d" % root_b], 2)
		"connected":
			var root_a := _find_rollback(a)
			var root_b := _find_rollback(b)
			connected_result = root_a == root_b
			outcome = "%d 与 %d%s连通" % [a, b, "" if connected_result else "不"]
			record("%s；查找过程未改写父指针" % outcome,
				["d%d" % root_a, "d%d" % root_b], 0)
		_:
			return fail("未知操作。")
	return true

func perform(action: String, args: Dictionary) -> bool:
	match kind:
		"weighted_disjoint_set":
			return _perform_weighted(action, args)
		"rollback_disjoint_set":
			return _perform_rollback(action, args)
		_:
			return _perform_standard(action, args)

func _children() -> Dictionary:
	var children := {}
	for i in range(1, count + 1):
		children[i] = []
	for i in range(1, count + 1):
		if parent[i] != i:
			children[parent[i]].append(i)
	for i in children:
		children[i].sort()
	return children

func _measure(id: int, children: Dictionary, widths: Dictionary) -> float:
	var width := 0.0
	for child in children[id]:
		width += _measure(child, children, widths)
	widths[id] = maxf(1.0, width)
	return widths[id]

func _node_lines(id: int) -> Array:
	if kind == "weighted_disjoint_set":
		if parent[id] == id:
			return [str(id), "ROOT", "w=0"]
		return [str(id), "fa=%d" % parent[id], "w=%d" % weight[id]]
	if parent[id] == id:
		if kind == "rollback_disjoint_set" or union_strategy == "size":
			return [str(id), "size=%d" % size[id]]
		if union_strategy == "rank":
			return [str(id), "rank=%d" % rank[id]]
		return [str(id), "ROOT"]
	return [str(id), "fa=%d" % parent[id]]

func _layout(id: int, depth: int, left: float, children: Dictionary,
		widths: Dictionary, nodes: Array, edges: Array) -> void:
	var span: float = widths[id] * HORIZONTAL_GAP
	var node := vertex("d%d" % id, id, left + span / 2.0, 85 + depth * 105,
		"", "circle", "green" if parent[id] == id else "")
	node["element"] = id
	node["lines"] = _node_lines(id)
	nodes.append(node)
	var child_left := left
	for child in children[id]:
		edges.append(edge("d%d" % child, "d%d" % id,
			"w=%d" % weight[child] if kind == "weighted_disjoint_set" else ""))
		_layout(child, depth + 1, child_left, children, widths, nodes, edges)
		child_left += widths[child] * HORIZONTAL_GAP

func _component_count() -> int:
	var total := 0
	for i in range(1, count + 1):
		if parent[i] == i:
			total += 1
	return total

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var children := _children()
	var widths := {}
	var left := 45.0
	for i in range(1, count + 1):
		if parent[i] != i:
			continue
		_measure(i, children, widths)
		_layout(i, 0, left, children, widths, nodes, edges)
		left += widths[i] * HORIZONTAL_GAP + ROOT_GAP
	var annotation := "箭头：x → fa[x]  ·  绿色：集合代表元"
	var stats := "元素 %d · 集合 %d" % [count, _component_count()]
	match kind:
		"weighted_disjoint_set":
			annotation += "  ·  w = value[x] - value[fa[x]]"
			stats += " · 带权（按 size + 路径压缩）"
		"rollback_disjoint_set":
			annotation += "  ·  根节点显示 size"
			stats += " · 历史 %d · 可撤销（无路径压缩）" % merge_history.size()
		_:
			var strategy_name: String = {
				"none": "不开启", "rank": "rank", "size": "size"
			}[union_strategy]
			stats += " · 路径压缩%s · 合并%s" % [
				"开启" if path_compression else "关闭", strategy_name
			]
	if not outcome.is_empty():
		stats += " · " + outcome
	return {
		"nodes": nodes,
		"edges": edges,
		"annotations": [{"pos": Vector2(45, 28), "text": annotation}],
		"parents": parent.duplicate(),
		"ranks": rank.duplicate(),
		"sizes": size.duplicate(),
		"weights": weight.duplicate(),
		"stats": stats
	}

func invariant() -> String:
	if parent.size() != count + 1 or rank.size() != count + 1 or \
			size.size() != count + 1 or weight.size() != count + 1:
		return "metadata array size"
	var actual_sizes: Array[int] = []
	for i in range(count + 1):
		actual_sizes.append(0)
	for start in range(1, count + 1):
		var seen := {}
		var current := start
		while parent[current] != current:
			if parent[current] < 1 or parent[current] > count:
				return "parent out of range"
			if seen.has(current):
				return "parent cycle"
			seen[current] = true
			current = parent[current]
		actual_sizes[current] += 1
	for i in range(1, count + 1):
		if parent[i] == i:
			if size[i] != actual_sizes[i]:
				return "root size"
			if kind == "weighted_disjoint_set" and weight[i] != 0:
				return "root weight"
	return ""
