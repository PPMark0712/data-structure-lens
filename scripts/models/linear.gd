class_name LinearModel
extends LabModel

var items: Array[Dictionary] = []
var capacity := 8
var stream_index := 0
var window := 3

func _init(p_kind: String = "array") -> void:
	super(p_kind)
	code.assign(["检查位置、容量或窗口边界", "逐个访问 / 比较元素",
		"按规则移动元素或修改连接", "更新长度、容量及头尾指针"])
	for value in [12, 7, 24, 16]:
		items.append({"id": uid(), "value": value, "index": stream_index})
		stream_index += 1
	if kind == "mono_stack" or kind == "mono_queue":
		items.clear()
		stream_index = 0
		recording = false
		for value in [12, 7, 24, 16]:
			_monotone(value)
		recording = true
	if kind == "dynamic_array":
		capacity = 4

func operations() -> Array:
	var value := field("value", "数值", "9")
	var index := field("index", "位置（0 起）", "1")
	var result: Array = []
	match kind:
		"stack", "mono_stack":
			result = [op("push", "入栈", [value]), op("pop", "出栈"), op("peek", "查看栈顶")]
		"queue":
			result = [op("push", "入队", [value]), op("pop", "出队"), op("peek", "查看队首")]
		"mono_queue":
			result = [op("push", "读入下一个值", [value]), op("peek", "窗口最大值")]
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
		stream_index = 0
		capacity = 4 if kind == "dynamic_array" else 8
		record("清空旧结构", [], 0)
		for value in values:
			if kind.begins_with("mono"):
				_monotone(value)
			else:
				_grow()
				items.append({"id": uid(), "value": value, "index": stream_index})
				stream_index += 1
				record("插入 %d" % value, [str(items.back().id)], 2)
		record("构建完成", [], 3)
		return true
	var index := int(args.get("index", 0))
	var value := int(args.get("value", 0))
	if action == "insert" and (index < 0 or index > items.size()):
		return fail("插入位置必须在 0 到 %d 之间。" % items.size())
	if action in ["delete", "update", "get"] and (index < 0 or index >= items.size()):
		return fail("该位置不存在。当前长度为 %d。" % items.size())
	if action in ["pop", "peek"] and items.is_empty():
		return fail("结构为空，无法读取或移除元素。")
	if action in ["push", "insert"] and not kind.begins_with("mono"):
		if items.size() >= (8 if kind == "array" else 16):
			return fail("已达到演示容量上限。")
	begin()
	match action:
		"push", "insert":
			if kind.begins_with("mono"):
				_monotone(value)
			else:
				if action == "push":
					index = items.size()
				_visit_to(index)
				_grow()
				var item := {"id": uid(), "value": value, "index": stream_index}
				stream_index += 1
				items.insert(index, item)
				record("在位置 %d 插入 %d，更新后继位置 / 连边" % [index, value], [str(item.id)], 2)
		"delete", "pop":
			if action == "pop":
				index = 0 if kind == "queue" else items.size() - 1
			_visit_to(index)
			record("移除 %s" % items[index].value, [str(items[index].id)], 2)
			items.remove_at(index)
			record("连接相邻元素，更新头尾和长度", [], 3)
		"update":
			_visit_to(index)
			items[index].value = value
			record("将位置 %d 修改为 %d" % [index, value], [str(items[index].id)], 2)
		"get", "peek":
			if action == "peek":
				index = 0 if kind in ["queue", "mono_queue"] else items.size() - 1
			_visit_to(index)
			record("查询结果：%s" % items[index].value, [str(items[index].id)], 3)
		"find":
			for i in items.size():
				record("比较位置 %d 的值 %s" % [i, items[i].value], [str(items[i].id)], 1)
				if items[i].value == value:
					record("找到 %d，位置为 %d" % [value, i], [str(items[i].id)], 3)
					return true
			record("未找到 %d" % value, [], 3)
	return true

func _visit_to(index: int) -> void:
	if kind in ["linked", "doubly"]:
		for i in mini(index + 1, items.size()):
			record("沿 next 指针访问第 %d 个节点" % i, [str(items[i].id)], 1)
	elif index < items.size():
		record("定位到位置 %d" % index, [str(items[index].id)], 1)

func _grow() -> void:
	if kind != "dynamic_array" or items.size() < capacity:
		return
	var old := capacity
	capacity *= 2
	record("容量不足：申请 %d → %d 个槽位" % [old, capacity], [], 0)
	for item in items:
		record("将元素 %s 复制到新存储区" % item.value, [str(item.id)], 2)
	record("复制完成，释放旧存储区；单次扩容 O(n)，append 均摊 O(1)", [], 3)

func _monotone(value: int) -> void:
	if kind == "mono_queue":
		while not items.is_empty() and items.front().index <= stream_index - window:
			record("下标 %d 已滑出长度 %d 的窗口，移除队首" % [items.front().index, window],
				[str(items.front().id)], 0)
			items.pop_front()
	while not items.is_empty():
		record("比较末尾 %s 与新值 %d" % [items.back().value, value], [str(items.back().id)], 1)
		var remove: bool = items.back().value <= value if kind == "mono_queue" else items.back().value >= value
		if not remove:
			break
		record("末尾元素无法保持单调性，弹出", [str(items.back().id)], 2)
		items.pop_back()
	# Bound visual size even for an indefinitely increasing input stream.
	if items.size() >= 16:
		record("演示栈已满，本次输入未加入", [], 0)
		return
	var item := {"id": uid(), "value": value, "index": stream_index}
	items.append(item)
	stream_index += 1
	record("加入 %d；%s" % [value, "队首为当前窗口最大值" if kind == "mono_queue" else "栈从底到顶严格递增"],
		[str(item.id)], 3)

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var linked := kind in ["linked", "doubly"]
	var stack := kind in ["stack", "mono_stack"]
	for i in items.size():
		var item := items[i]
		var x := 150.0 if stack else 75.0 + i * (110.0 if linked else 78.0)
		var y := 660.0 - i * 68.0 if stack else 200.0
		var detail := "[%d]" % i
		if kind == "mono_queue":
			detail = "t=%d" % item.index
		if stack and i == items.size() - 1:
			detail += " TOP"
		if kind in ["queue", "mono_queue", "linked", "doubly"]:
			if i == 0: detail += " HEAD"
			if i == items.size() - 1: detail += " TAIL"
		nodes.append(vertex(item.id, item.value, x, y, detail, "circle" if linked else "box"))
		if linked and i > 0:
			edges.append(edge(items[i - 1].id, item.id, "next"))
			if kind == "doubly":
				edges.append(edge(item.id, items[i - 1].id, "prev", true))
	if kind in ["array", "dynamic_array"]:
		for i in range(items.size(), capacity):
			nodes.append(vertex("empty%d" % i, "·", 75 + i * 78, 200, "[%d]" % i, "box", "muted"))
	var stats := "长度 %d" % items.size()
	if kind in ["array", "dynamic_array"]:
		stats += "  /  容量 %d" % capacity
	if kind == "mono_queue":
		stats += "  ·  窗口长度 %d  ·  已读入 %d 个值" % [window, stream_index]
	return {"nodes": nodes, "edges": edges, "stats": stats}

func invariant() -> String:
	if kind in ["array", "dynamic_array"] and items.size() > capacity:
		return "size > capacity"
	for i in range(1, items.size()):
		if kind == "mono_stack" and items[i - 1].value >= items[i].value:
			return "monotone stack order"
		if kind == "mono_queue" and items[i - 1].value <= items[i].value:
			return "monotone queue order"
	return ""
