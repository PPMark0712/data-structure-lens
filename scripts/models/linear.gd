class_name LinearModel
extends LabModel

var items: Array[Dictionary] = []
var capacity := 8
var stream_index := 0
var window := 3
var head := 0
var tail := 0
var visual_slots: Dictionary = {}

func _init(p_kind: String = "array") -> void:
	super(p_kind)
	code.assign(["检查位置、容量或窗口边界", "逐个访问 / 比较元素",
		"按规则移动元素或修改连接", "更新长度、容量及头尾指针"])
	for value in [12, 7, 24, 16]:
		_insert_at(items.size(), {"id": uid(), "value": value, "index": stream_index})
		stream_index += 1
	if kind == "dynamic_array":
		capacity = 4

func operations() -> Array:
	var value := field("value", "数值", "9")
	var index := field("index", "位置（1 起；1 为头插）", "1")
	var result: Array = []
	match kind:
		"stack":
			result = [op("push", "入栈", [value]), op("pop", "出栈"), op("peek", "查看栈顶")]
		"queue":
			result = [op("push", "入队", [value]), op("pop", "出队"), op("peek", "查看队首")]
		_:
			result = [op("insert", "插入", [index, value]), op("delete", "删除", [index]),
				op("update", "修改", [index, value]), op("get", "按位置查询", [index]),
				op("find", "查找值", [value])]
			if kind == "dynamic_array":
				result.push_front(op("push", "Append", [value]))
	result.append(op("build", "重新构建", [field("values", "整数序列", "12,7,24,16", true)]))
	return result

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		error = ""
		var values := integers(str(args.values))
		if not error.is_empty():
			return false
		if kind == "array" and values.size() > 8:
			return fail("静态数组容量为 8，不能扩容。")
		begin()
		items.clear()
		head = 0
		tail = 0
		stream_index = 0
		capacity = 4 if kind == "dynamic_array" else 8
		record("清空旧结构", [], 0)
		for value in values:
			_grow()
			_insert_at(items.size(), {"id": uid(), "value": value, "index": stream_index})
			stream_index += 1
			record("插入 %d" % value, [str(items.back().id)], 2)
		record("构建完成", [], 3)
		return true
	var index := int(args.get("index", 1)) - 1
	var value := int(args.get("value", 0))
	if action == "insert" and (index < 0 or index > items.size()):
		return fail("插入位置必须在 1 到 %d 之间；1 为头插，%d 为尾插。" % [items.size() + 1, items.size() + 1])
	if action in ["delete", "update", "get"] and (index < 0 or index >= items.size()):
		return fail("该位置不存在。当前长度为 %d。" % items.size())
	if action in ["pop", "peek"] and items.is_empty():
		return fail("结构为空，无法读取或移除元素。")
	if action in ["push", "insert"]:
		if items.size() >= (8 if kind == "array" else 16):
			return fail("已达到演示容量上限。")
	begin()
	match action:
		"push", "insert":
			if action == "push":
				index = items.size()
			_visit_to(index)
			_grow()
			if kind in ["array", "dynamic_array"]:
				for i in range(items.size() - 1, index - 1, -1):
					visual_slots[items[i].id] = i + 1
					record("将 %s 从位置 %d 右移到 %d，为插入腾出空位" % [items[i].value, i + 1, i + 2],
						[str(items[i].id)], 2)
			var item := {"id": uid(), "value": value, "index": stream_index}
			stream_index += 1
			_insert_at(index, item)
			visual_slots.clear()
			record("在位置 %d 插入 %d，更新长度及头尾指针" % [index + 1, value], [str(item.id)], 3)
		"delete", "pop":
			if action == "pop":
				index = 0 if kind == "queue" else items.size() - 1
			_visit_to(index)
			record("移除 %s" % items[index].value, [str(items[index].id)], 2)
			_remove_at(index)
			record("连接相邻元素，更新头尾和长度", [], 3)
		"update":
			_visit_to(index)
			items[index].value = value
			record("将位置 %d 修改为 %d" % [index + 1, value], [str(items[index].id)], 2)
		"get", "peek":
			if action == "peek":
				index = 0 if kind == "queue" else items.size() - 1
			_visit_to(index)
			record("查询结果：%s" % items[index].value, [str(items[index].id)], 3)
		"find":
			for i in items.size():
				record("比较位置 %d 的值 %s" % [i + 1, items[i].value], [str(items[i].id)], 1)
				if items[i].value == value:
					record("找到 %d，位置为 %d" % [value, i + 1], [str(items[i].id)], 3)
					return true
			record("未找到 %d" % value, [], 3)
	return true

func _by_id(id: int) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}

func _insert_at(index: int, item: Dictionary) -> void:
	if kind in ["linked", "doubly"]:
		var previous: int = items[index - 1].id if index else 0
		var next: int = items[index].id if index < items.size() else 0
		item["next"] = next
		item["prev"] = previous if kind == "doubly" else 0
		if previous: _by_id(previous).next = item.id
		else: head = item.id
		if next and kind == "doubly": _by_id(next).prev = item.id
		if not next: tail = item.id
	items.insert(index, item)

func _remove_at(index: int) -> void:
	if kind in ["linked", "doubly"]:
		var previous: int = items[index - 1].id if index else 0
		var next: int = items[index].next
		if previous: _by_id(previous).next = next
		else: head = next
		if next and kind == "doubly": _by_id(next).prev = previous
		if not next: tail = previous
	items.remove_at(index)

func _visit_to(index: int) -> void:
	if kind in ["linked", "doubly"]:
		var id := head
		for i in mini(index + 1, items.size()):
			record("沿 next 指针访问第 %d 个节点" % [i + 1], [str(id)], 1)
			id = _by_id(id).next
	elif index < items.size():
		record("定位到位置 %d" % [index + 1], [str(items[index].id)], 1)

func _grow() -> void:
	if kind != "dynamic_array" or items.size() < capacity:
		return
	var old := capacity
	capacity *= 2
	record("容量不足：申请 %d → %d 个槽位" % [old, capacity], [], 0)
	for item in items:
		record("将元素 %s 复制到新存储区" % item.value, [str(item.id)], 2)
	record("复制完成，释放旧存储区；单次扩容 O(n)，append 均摊 O(1)", [], 3)

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var linked := kind in ["linked", "doubly"]
	var stack := kind == "stack"
	var occupied := {}
	for i in items.size():
		var item := items[i]
		var slot: int = visual_slots.get(item.id, i)
		occupied[slot] = true
		var x := 150.0 if stack else 75.0 + slot * (110.0 if linked else 78.0)
		var y := 660.0 - i * 68.0 if stack else 200.0
		var detail := "[%d]" % [slot + 1]
		if stack and i == items.size() - 1:
			detail += " TOP"
		if kind in ["queue", "linked", "doubly"]:
			if i == 0: detail += " HEAD"
			if i == items.size() - 1: detail += " TAIL"
		nodes.append(vertex(item.id, item.value, x, y, detail, "circle" if linked else "box"))
		if linked:
			if item.next: edges.append(edge(item.id, item.next, "next"))
			if kind == "doubly" and item.prev:
				edges.append(edge(item.id, item.prev, "prev", true))
	if kind in ["array", "dynamic_array"]:
		for i in capacity:
			if not occupied.has(i):
				nodes.append(vertex("empty%d" % i, "·", 75 + i * 78, 200, "[%d]" % [i + 1], "box", "muted"))
	var stats := "长度 %d" % items.size()
	if kind in ["array", "dynamic_array"]:
		stats += "  /  容量 %d" % capacity
	return {"nodes": nodes, "edges": edges, "stats": stats}

func invariant() -> String:
	if kind in ["array", "dynamic_array"] and items.size() > capacity:
		return "size > capacity"
	if kind in ["linked", "doubly"]:
		if head != (items[0].id if not items.is_empty() else 0): return "list head"
		if tail != (items[-1].id if not items.is_empty() else 0): return "list tail"
		for i in items.size():
			if items[i].next != (items[i + 1].id if i + 1 < items.size() else 0):
				return "list next pointer"
			if kind == "doubly" and items[i].prev != (items[i - 1].id if i else 0):
				return "list prev pointer"
	return ""
