class_name TrieModel
extends LabModel

var pool := {}
var root := 0
var roots: Array = []
var version := 0
var values: Array = []
var histories: Array = []
var result := 0
var matched := 0

func _init(p_kind: String = "trie") -> void:
	super(p_kind)
	code.assign(["从根出发，读取下一个字符 / 位", "沿边查找；不存在时创建节点",
		"更新经过计数与终止计数", "删除后回溯，回收计数为零的分支",
		"异或查询：优先选择与当前位相反的分支", "持久化：复制路径，保留其他分支"])
	recording = false
	root = _node("", 0)
	for value in (["cat", "car", "dog"] if kind == "trie" else [5, 12, 25]):
		_insert(root, _letters(value))
		values.append(value)
	roots.append(root)
	histories.append(values.duplicate())
	recording = true

func operations() -> Array:
	var spec := field("value", "小写英文单词（1–8 字母）", "can", true) if kind == "trie" else field("value", "整数（0–255）", "10")
	var ops := [op("insert", "插入", [spec])]
	if kind != "persistent_trie":
		ops.append(op("delete", "删除一次", [field("value", "单词", "cat", true) if kind == "trie" else field("value", "整数", "5")]))
	if kind == "trie":
		ops.append(op("find", "查询词频", [field("value", "单词", "cat", true)]))
		ops.append(op("prefix", "查询前缀计数", [field("value", "前缀", "ca", true)]))
	else:
		ops.append(op("xor", "最大异或", [field("value", "与谁异或（0–255）", "7")]))
	if kind == "persistent_trie":
		ops.append(op("version", "切换历史版本", [field("version", "版本号（1 起）", "1")]))
	return ops

func _node(letter: String, depth: int) -> int:
	var id := uid()
	pool[id] = {"letter": letter, "depth": depth, "count": 0, "end": 0, "children": {}}
	return id

func _letters(value: Variant) -> Array:
	var letters: Array = []
	if kind == "trie":
		for letter in str(value): letters.append(letter)
	else:
		for bit in range(7, -1, -1): letters.append(str((int(value) >> bit) & 1))
	return letters

func _valid(value: Variant) -> bool:
	if kind != "trie":
		return true if int(value) >= 0 and int(value) <= 255 else fail("01 Trie 仅接受 0–255。")
	var text := str(value)
	if text.is_empty() or text.length() > 8: return fail("请输入 1–8 个小写英文字母。")
	for letter in text:
		if letter < "a" or letter > "z": return fail("仅支持小写英文字母 a–z。")
	return true

func _insert(start: int, letters: Array) -> void:
	var id := start
	pool[id].count += 1
	for letter in letters:
		calls.append("沿 '%s' 边" % letter)
		record("读取字符 / 位 '%s'" % letter, [str(id)], 0)
		if not pool[id].children.has(letter):
			pool[id].children[letter] = _node(letter, pool[id].depth + 1)
			record("创建 '%s' 分支" % letter, [str(id)], 1)
		id = pool[id].children[letter]
		pool[id].count += 1
		record("经过计数 +1", [str(id)], 2)
	pool[id].end += 1
	record("终止计数 +1：此处保存完整键", [str(id)], 2)
	calls.clear()

func _copy_insert(old: int, letters: Array, depth: int) -> int:
	var id := uid()
	pool[id] = pool[old].duplicate(true)
	pool[id].count += 1
	calls.append("clone #%d → #%d" % [old, id])
	record("复制路径节点；旧节点与其他分支保持不变", [str(old), str(id)], 5)
	if depth == letters.size():
		pool[id].end += 1
	else:
		var letter: String = letters[depth]
		var child: int = pool[id].children.get(letter, 0)
		if child:
			pool[id].children[letter] = _copy_insert(child, letters, depth + 1)
		else:
			child = _node(letter, depth + 1)
			pool[id].children[letter] = child
			_insert(child, letters.slice(depth + 1))
	calls.pop_back()
	return id

func _walk(letters: Array) -> int:
	var id := root
	for letter in letters:
		record("查找 '%s' 分支" % letter, [str(id)], 0)
		if not pool[id].children.has(letter): return 0
		id = pool[id].children[letter]
	return id

func perform(action: String, args: Dictionary) -> bool:
	if action == "version":
		var target := int(args.version) - 1
		if target < 0 or target >= roots.size(): return fail("版本不存在。")
		begin()
		version = target
		root = roots[version]
		values = histories[version].duplicate()
		record("切换到 V%d" % [version + 1], [str(root)], 5)
		return true
	var value: Variant = args.value
	if not _valid(value): return false
	if action == "insert":
		if values.size() >= 16: return fail("每个版本最多 16 个键（含重复）。")
		if kind == "persistent_trie" and roots.size() >= 6: return fail("最多演示 6 个版本。")
	if action == "delete" and not values.has(value): return fail("键不存在，无法删除。")
	if action == "xor" and values.is_empty(): return fail("空 Trie 无法查询最大异或。")
	begin()
	var letters := _letters(value)
	match action:
		"insert":
			if kind == "persistent_trie": root = _copy_insert(root, letters, 0)
			else: _insert(root, letters)
			values.append(value)
			if kind == "persistent_trie":
				roots.append(root)
				histories.append(values.duplicate())
				version = roots.size() - 1
		"delete":
			var path: Array = [root]
			var id := root
			for letter in letters:
				id = pool[id].children[letter]
				path.append(id)
				record("沿删除路径访问节点", [str(id)], 0)
			pool[id].end -= 1
			for item in path: pool[item].count -= 1
			for i in range(path.size() - 1, 0, -1):
				id = path[i]
				if pool[id].count == 0:
					pool[path[i - 1]].children.erase(letters[i - 1])
					pool.erase(id)
					record("回溯：移除计数为零的分支", [str(path[i - 1])], 3)
			values.erase(value)
		"find", "prefix":
			var id := _walk(letters)
			result = pool[id]["end" if action == "find" else "count"] if id else 0
			record("%s '%s' 的计数 = %d" % ["单词" if action == "find" else "前缀", value, result], [str(id)], 2)
		"xor":
			var id := root
			matched = 0
			for bit in range(7, -1, -1):
				var current := (int(value) >> bit) & 1
				var chosen := str(1 - current)
				if not pool[id].children.has(chosen): chosen = str(current)
				id = pool[id].children[chosen]
				matched = (matched << 1) | int(chosen)
				record("第 %d 位（最低位为 1）选 %s；%s" % [bit + 1, chosen, "得到异或位 1" if int(chosen) != current else "只能取同位"], [str(id)], 4)
			result = int(value) ^ matched
			record("最大异或：%d XOR %d = %d" % [value, matched, result], [str(id)], 4)
	record("操作完成 · 当前共 %d 个键%s" % [values.size(), " · V%d" % [version + 1] if kind == "persistent_trie" else ""])
	return true

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var annotations: Array = []
	var levels := {}
	for id in pool:
		var depth: int = pool[id].depth
		if not levels.has(depth): levels[depth] = []
		levels[depth].append(id)
	for depth in levels:
		for i in levels[depth].size():
			var id: int = levels[depth][i]
			var n: Dictionary = pool[id]
			var v := roots.find(id)
			var node := vertex(id, "#%d" % id, 70 + i * 100, 60 + depth * 105,
				"", "circle", "green" if id == root or n.end > 0 else "")
			node["lines"] = ["#%d" % id, "%d/%d" % [n.count, n.end]]
			nodes.append(node)
			if v >= 0 and kind == "persistent_trie":
				annotations.append({"pos": node.pos + Vector2(-15, -40), "text": "V%d" % [v + 1]})
			for letter in n.children: edges.append(edge(id, n.children[letter], letter))
	return {"nodes": nodes, "edges": edges, "annotations": annotations, "stats":
		"键 %d · 节点 %d · 计数=经过/终止%s" % [values.size(), pool.size(),
		" · V%d / %d 版本" % [version + 1, roots.size()] if kind == "persistent_trie" else ""]}

func invariant() -> String:
	for id in pool:
		var n: Dictionary = pool[id]
		var total: int = n.end
		for letter in n.children:
			var child: int = n.children[letter]
			if pool[child].depth != n.depth + 1 or pool[child].letter != letter: return "trie edge"
			total += pool[child].count
		if n.count != total or total < 0: return "trie count"
	if pool[root].count != values.size(): return "trie size"
	for v in roots.size():
		if kind == "persistent_trie" and pool[roots[v]].count != histories[v].size():
			return "trie historical version"
	return ""
