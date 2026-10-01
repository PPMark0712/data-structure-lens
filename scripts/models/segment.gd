class_name SegmentModel
extends LabModel

var pool: Dictionary = {}
var root := 0
var roots: Array[int] = []
var version_data: Array = []
var version := 0
var data: Array = []
var result := 0
var domain := 8
var visited: Array[int] = []
var used: Array[int] = []
var selected_range: Array[int] = []

func _init(p_kind: String = "segment") -> void:
	super(p_kind)
	code.assign(["进入节点 [l,r]，检查覆盖关系", "完全覆盖：sum += Δ×长度，lazy += Δ",
		"下传 lazy / 按需开点 / 复制路径", "递归左右子树", "回溯：sum = left.sum + right.sum"])
	recording = false
	if kind == "dynamic_segment":
		domain = 32
		data.resize(domain)
		data.fill(0)
		root = _new_node(1, domain)
		for index in [4, 13, 25]:
			_add(root, index, index, index)
			data[index - 1] += index
	else:
		data = [3, 1, 4, 1, 5, 9, 2, 6]
		root = _build(1, 8)
	roots.append(root)
	version_data.append(data.duplicate())
	recording = true

func operations() -> Array:
	var result_ops: Array = []
	if kind == "segment":
		result_ops.append(op("add", "区间增加", [field("l", "左端点（1 起）", "2"),
			field("r", "右端点（含）", "6"), field("value", "增量", "5")]))
	else:
		result_ops.append(op("add", "单点增加", [field("index", "下标（1–%d）" % domain, "3"),
			field("value", "增量", "5")]))
	result_ops.append(op("query", "区间求和", [field("l", "左端点（1 起）", "1"),
		field("r", "右端点（含）", "6")]))
	if kind == "persistent_segment":
		result_ops.append(op("version", "切换历史版本", [field("version", "版本号（1 起）", "1")]))
	return result_ops

func _new_node(l: int, r: int) -> int:
	var id := uid()
	pool[id] = {"l": l, "r": r, "sum": 0, "tag": 0, "left": 0, "right": 0}
	return id

func _build(l: int, r: int) -> int:
	var id := _new_node(l, r)
	if l == r:
		pool[id].sum = data[l - 1]
	else:
		var mid := (l + r) >> 1
		pool[id].left = _build(l, mid)
		pool[id].right = _build(mid + 1, r)
		_pull(id)
	return id

func _sum(id: int) -> int:
	return pool[id].sum if id else 0

func _pull(id: int) -> void:
	pool[id].sum = _sum(pool[id].left) + _sum(pool[id].right)

func _apply(id: int, delta: int) -> void:
	pool[id].sum += delta * (pool[id].r - pool[id].l + 1)
	pool[id].tag += delta

func _children(id: int) -> void:
	var node: Dictionary = pool[id]
	if node.l == node.r: return
	var mid: int = (node.l + node.r) >> 1
	if not node.left:
		node.left = _new_node(node.l, mid)
		record("按需创建左子节点 [%d,%d]" % [node.l, mid], [str(node.left)], 2)
	if not node.right:
		node.right = _new_node(mid + 1, node.r)
		record("按需创建右子节点 [%d,%d]" % [mid + 1, node.r], [str(node.right)], 2)
	if node.tag != 0:
		var pending: int = node.tag
		_apply(node.left, pending)
		_apply(node.right, pending)
		node.tag = 0
		if kind == "segment":
			for child in [node.left, node.right]:
				if not visited.has(child): visited.append(child)
		record("下传 lazy=%d 到两个子区间，清空父节点标记" % pending,
			[str(id), str(node.left), str(node.right)], 2)

func perform(action: String, args: Dictionary) -> bool:
	if action == "version":
		var target := int(args.version) - 1
		if target < 0 or target >= roots.size(): return fail("该版本不存在。")
		begin()
		version = target
		root = roots[version]
		data = version_data[version].duplicate()
		record("切换到版本 V%d；共享节点保持不变" % [version + 1], [str(root)], 0)
		return true
	var l := int(args.get("l", args.get("index", 1)))
	var r := int(args.get("r", l))
	if l < 1 or r > domain or l > r:
		return fail("区间必须满足 1 ≤ l ≤ r ≤ %d。" % domain)
	if kind == "persistent_segment" and action == "add" and roots.size() >= 6:
		return fail("最多演示 6 个版本；可恢复默认后重新实验。")
	begin()
	if kind == "segment":
		visited.clear()
		used.clear()
		selected_range.assign([l, r])
	if action == "add":
		var delta := int(args.value)
		if kind == "persistent_segment":
			var previous_version := version
			root = _copy_add(root, l, delta)
			data[l - 1] += delta
			roots.append(root)
			version_data.append(data.duplicate())
			version = roots.size() - 1
			record("从 V%d 创建 V%d；只复制根到叶路径" % [previous_version + 1, version + 1], [str(root)], 4)
		else:
			_add(root, l, r, delta)
			if kind != "segment":
				for i in range(l, r + 1): data[i - 1] += delta
			record("更新 [%d,%d] 完成；根区间和 = %d" % [l, r, _sum(root)],
				[] if kind == "segment" else [str(root)], 4)
	else:
		result = _query(root, l, r)
		record("区间 [%d,%d] 的和 = %d" % [l, r, result], [], 4)
	return true

func _add(id: int, l: int, r: int, delta: int) -> void:
	var node: Dictionary = pool[id]
	if kind == "segment" and not visited.has(id): visited.append(id)
	calls.append("add([%d,%d], Δ=%d)" % [node.l, node.r, delta])
	record("访问区间 [%d,%d]" % [node.l, node.r], [str(id)], 0)
	if l <= node.l and node.r <= r:
		_apply(id, delta)
		if kind == "segment":
			used.append(id)
			for i in range(node.l, node.r + 1): data[i - 1] += delta
		record("完全覆盖：sum += %d × %d，lazy += %d" % [delta, node.r - node.l + 1, delta], [str(id)], 1)
	else:
		if kind == "dynamic_segment":
			var mid: int = (node.l + node.r) >> 1
			# Allocate only the branch reached by this point update.
			var side := "left" if l <= mid else "right"
			if node[side] == 0:
				node[side] = _new_node(node.l if side == "left" else mid + 1, mid if side == "left" else node.r)
				record("动态开点：新建节点 #%d" % node[side], [str(node[side])], 2)
			_add(node[side], l, r, delta)
		else:
			_children(id)
			var mid: int = (node.l + node.r) >> 1
			if l <= mid: _add(node.left, l, r, delta)
			if r > mid: _add(node.right, l, r, delta)
		_pull(id)
		record("回溯 [%d,%d]：sum = %d" % [node.l, node.r, node.sum], [str(id)], 4)
	calls.pop_back()

func _copy_add(old: int, index: int, delta: int) -> int:
	var id := uid()
	pool[id] = pool[old].duplicate(true)
	var node: Dictionary = pool[id]
	calls.append("clone #%d → #%d [%d,%d]" % [old, id, node.l, node.r])
	record("复制节点 #%d，新节点 #%d；旧节点不修改" % [old, id], [str(old), str(id)], 2)
	if node.l == node.r:
		node.sum += delta
	else:
		var mid: int = (node.l + node.r) >> 1
		if index <= mid: node.left = _copy_add(node.left, index, delta)
		else: node.right = _copy_add(node.right, index, delta)
		_pull(id)
	record("新节点 #%d 的区间和为 %d" % [id, node.sum], [str(id)], 4)
	calls.pop_back()
	return id

func _query(id: int, l: int, r: int) -> int:
	if id == 0: return 0
	var node: Dictionary = pool[id]
	if r < node.l or l > node.r: return 0
	if kind == "segment" and not visited.has(id): visited.append(id)
	calls.append("query([%d,%d])" % [node.l, node.r])
	record("查询访问 [%d,%d]" % [node.l, node.r], [str(id)], 0)
	var answer := 0
	if l <= node.l and node.r <= r:
		answer = node.sum
		if kind == "segment": used.append(id)
		record("完全覆盖，直接返回 sum=%d" % answer, [str(id)], 1)
	else:
		if kind == "segment": _children(id)
		answer = _query(node.left, l, r) + _query(node.right, l, r)
		record("合并子区间返回值 = %d" % answer, [str(id)], 4)
	calls.pop_back()
	return answer

func view() -> Dictionary:
	if kind == "segment": return _interval_view()
	var nodes: Array = []
	var edges: Array = []
	var levels := {}
	for id in pool:
		var n: Dictionary = pool[id]
		var depth := 0
		var length := domain
		while length > n.r - n.l + 1:
			depth += 1
			length = (length + 1) >> 1
		if not levels.has(depth): levels[depth] = []
		levels[depth].append(id)
	for depth in levels:
		for column in levels[depth].size():
			var id: int = levels[depth][column]
			var n: Dictionary = pool[id]
			var x: float
			if kind == "persistent_segment":
				x = 70 + column * 110
			else:
				x = 50 + float(n.l + n.r - 2) / 2 * (95 if domain == 8 else 35)
			var label := "[%d,%d]" % [n.l, n.r]
			if n.tag != 0: label += " +%d" % n.tag
			var v := roots.find(id)
			if v >= 0 and kind == "persistent_segment": label = "V%d " % [v + 1] + label
			nodes.append(vertex(id, n.sum, x, 80 + depth * 115, label, "circle", "green" if id == root else ""))
			if n.left: edges.append(edge(id, n.left))
			if n.right: edges.append(edge(id, n.right))
	return {"nodes": nodes, "edges": edges, "stats":
		"范围 [1,%d]  ·  已分配 %d 个节点%s" % [domain, pool.size(),
		"  ·  当前 V%d / 共 %d 个版本" % [version + 1, roots.size()] if kind == "persistent_segment" else ""]}

func _interval_view() -> Dictionary:
	var nodes: Array = []
	var annotations: Array = [{"pos": Vector2(40, 30), "text": "原数组 · 当前数值"}]
	for i in domain:
		var tone := "green" if not selected_range.is_empty() and i + 1 >= selected_range[0] and i + 1 <= selected_range[1] else ""
		var cell := vertex("a%d" % [i + 1], data[i], 40 + (i + 0.5) * 100, 75, "[%d]" % [i + 1], "box", tone)
		cell["size"] = Vector2(100, 40)
		nodes.append(cell)
	for id in pool:
		var n: Dictionary = pool[id]
		var length: int = n.r - n.l + 1
		var depth := 0
		var span := domain
		while span > length:
			span >>= 1
			depth += 1
		var tone := "green" if used.has(id) else ("blue" if visited.has(id) else "")
		var bar := vertex(id, n.sum, 40 + (n.l - 1 + length / 2.0) * 100,
			190 + depth * 100, "", "box", tone)
		bar["size"] = Vector2(length * 100, 64)
		bar["lines"] = ["[%d,%d]" % [n.l, n.r], "sum=%d" % n.sum, "lazy=%d" % n.tag]
		bar["range"] = [n.l, n.r]
		nodes.append(bar)
	annotations.append({"pos": Vector2(40, 565), "text": "浅蓝：递归访问 / 下传    绿色：直接更新或取和的区间、原数组目标范围"})
	var pieces: Array[String] = []
	for id in used: pieces.append("[%d,%d]" % [pool[id].l, pool[id].r])
	if not pieces.is_empty():
		annotations.append({"pos": Vector2(40, 595), "text": "本次区间拆分：" + " + ".join(pieces) +
			"  →  原数组 [%d,%d]" % [selected_range[0], selected_range[1]]})
	return {"nodes": nodes, "edges": [], "annotations": annotations,
		"stats": "范围 [1,%d]  ·  sum=区间和  ·  lazy=待下传增量" % domain}

func invariant() -> String:
	for id in pool:
		var node: Dictionary = pool[id]
		if node.l < node.r:
			var expected := _sum(node.left) + _sum(node.right) + int(node.tag) * (int(node.r) - int(node.l) + 1)
			if node.sum != expected: return "segment pull / lazy mismatch"
	var expected := 0
	for value in data: expected += value
	if _sum(root) != expected: return "segment root sum mismatch"
	if kind == "persistent_segment":
		for v in roots.size():
			var total := 0
			for value in version_data[v]: total += value
			if _sum(roots[v]) != total: return "historical version mutated"
	return ""
