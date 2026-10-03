class_name LinearModel
extends LabModel

var items: Array[Dictionary] = []
var capacity := 8
var stream_index := 0
var window := 3
var head := 0
var tail := 0
var visual_slots: Dictionary = {}
var migration: Dictionary = {}
var reversal: Dictionary = {}

func _init(p_kind: String = "array") -> void:
	super(p_kind)
	code.assign(["检查位置、容量或窗口边界", "逐个访问 / 比较元素",
		"按规则移动元素或修改连接", "更新长度、容量及头尾指针"])
	for value in [12, 7, 24, 16]:
		_insert_at(items.size(), {"id": uid(), "value": value, "index": stream_index})
		stream_index += 1
	if kind == "dynamic_array":
		capacity = 4
		code.assign(["检查位置和容量；满时申请两倍内存", "定位元素 / 读取旧内存",
			"逐个向下复制 / 在数组内移动元素", "切换内存、释放旧块，更新长度"])
	elif kind == "linked":
		code.assign(["检查位置、k 或翻转区间", "沿 next 访问；翻转时保存 pre 与后继",
			"在下方逐个反转 next", "用 pre / HEAD 与后继重连"])

func operations() -> Array:
	var value := field("value", "数值", "9")
	var index := field("index", "位置（1 起；1 为头插）", "1")
	var kth := field("index", "k（1 起）", "2")
	var result: Array = []
	match kind:
		"stack":
			result = [op("push", "入栈", [value]), op("pop", "出栈"), op("peek", "查看栈顶")]
		"queue":
			result = [op("push", "入队", [value]), op("pop", "出队"), op("peek", "查看队首")]
		"linked":
			result = [op("insert_head", "头插", [value]), op("insert_tail", "尾插", [value]),
				op("delete", "删除", [index]), op("get", "查询第 k 个", [kth]),
				op("get_from_end", "查询倒数第 k 个", [kth]),
				op("reverse_range", "翻转第 i 到第 j 个", [
					field("l", "i（1 起）", "2"), field("r", "j（含）", "4")]),
				op("find", "查找值", [value])]
		"doubly":
			result = [op("insert", "插入", [index, value]), op("delete", "删除", [index]),
				op("get", "查询第 k 个", [kth]),
				op("get_from_end", "查询倒数第 k 个", [kth]),
				op("find", "查找值", [value])]
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
	if kind == "linked" and action == "insert":
		return fail("单向链表只支持头插和尾插。")
	if kind in ["linked", "doubly"] and action == "update":
		return fail("链表不提供修改节点值操作。")
	if action == "get_from_end" and kind not in ["linked", "doubly"]:
		return fail("仅链表支持查询倒数第 k 个节点。")
	if action == "reverse_range" and kind != "linked":
		return fail("仅单向链表支持区间翻转。")
	if action == "insert" and (index < 0 or index > items.size()):
		return fail("插入位置必须在 1 到 %d 之间；1 为头插，%d 为尾插。" % [items.size() + 1, items.size() + 1])
	if action in ["delete", "update", "get", "get_from_end"] and (index < 0 or index >= items.size()):
		return fail("该位置不存在。当前长度为 %d。" % items.size())
	var left := int(args.get("l", 1)) - 1
	var right := int(args.get("r", 1)) - 1
	if action == "reverse_range" and (left < 0 or right < left or right >= items.size()):
		return fail("翻转区间必须满足 1 ≤ i ≤ j ≤ %d。" % items.size())
	if action in ["pop", "peek"] and items.is_empty():
		return fail("结构为空，无法读取或移除元素。")
	if action in ["push", "insert", "insert_head", "insert_tail"]:
		if items.size() >= (8 if kind == "array" else 16):
			return fail("已达到演示容量上限。")
	begin()
	match action:
		"push", "insert", "insert_head", "insert_tail":
			if action == "push":
				index = items.size()
			elif action == "insert_head":
				index = 0
			elif action == "insert_tail":
				index = items.size()
			if action == "insert_head":
				record("读取 HEAD，准备在链首插入", [str(head)] if head else [], 1)
			elif action == "insert_tail":
				record("读取 TAIL，准备在链尾插入", [str(tail)] if tail else [], 1)
			else:
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
			if kind == "stack":
				visual_slots[item.id] = index + 1
				record("将 %d 从栈口放入" % value, [str(item.id)], 2)
				visual_slots[item.id] = index
				record("%d 落到栈顶，更新 TOP 和长度" % value, [str(item.id)], 3)
				visual_slots.clear()
			else:
				visual_slots.clear()
				if action in ["insert_head", "insert_tail"] and items.size() == 1:
					record("空链表插入新节点，HEAD 和 TAIL 均指向它",
						[str(item.id)], 3)
				elif action == "insert_head":
					record("新节点 next 指向原首节点，更新 HEAD 和长度", [str(item.id)], 3)
				elif action == "insert_tail":
					record("原尾节点 next 指向新节点，更新 TAIL 和长度", [str(item.id)], 3)
				else:
					record("在位置 %d 插入 %d，更新长度及头尾指针" % [index + 1, value], [str(item.id)], 3)
		"delete", "pop":
			if action == "pop":
				index = 0 if kind == "queue" else items.size() - 1
			if kind == "linked" and index > 0:
				_visit_to(index - 1)
			else:
				_visit_to(index)
			var removed: Dictionary = items[index]
			if kind in ["array", "dynamic_array"]:
				_remove_at(index)
				for i in range(index, items.size()):
					visual_slots[items[i].id] = i + 1
				record("移除位置 %d 的 %s，留下一个空位" % [index + 1, removed.value], [], 2)
				for i in range(index, items.size()):
					visual_slots[items[i].id] = i
					record("将 %s 从位置 %d 左移到 %d，填补空位" %
						[items[i].value, i + 2, i + 1], [str(items[i].id)], 2)
				visual_slots.clear()
				record("左移完成，更新数组长度", [], 3)
			else:
				if kind == "stack":
					visual_slots[removed.id] = index + 1
					record("将栈顶 %s 从栈口取出" % removed.value, [str(removed.id)], 2)
					_remove_at(index)
					visual_slots.clear()
					record("更新 TOP 和长度", [], 3)
				elif kind == "linked":
					if index == 0:
						var was_singleton := items.size() == 1
						record("HEAD 指向待删除节点 %s，删除首节点" % removed.value,
							[str(removed.id)], 2)
						_remove_at(index)
						if was_singleton:
							record("链表变空，HEAD 和 TAIL 均指向 NULL", [], 3)
						else:
							record("HEAD 改指向原第二个节点，长度减一", [str(head)], 3)
					else:
						var previous: Dictionary = items[index - 1]
						var removes_tail: bool = removed.id == tail
						record("节点 %s 的 next 是待删除节点 %s，删除 next" %
							[previous.value, removed.value],
							[str(previous.id), str(removed.id)], 2)
						_remove_after(index - 1)
						if removes_tail:
							record("前驱 next 改为 NULL，TAIL 改为前驱，长度减一",
								[str(previous.id)], 3)
						else:
							record("前驱 next 改指向目标的后继，长度减一",
								[str(previous.id)], 3)
				else:
					record("移除 %s" % removed.value, [str(removed.id)], 2)
					_remove_at(index)
				if kind == "doubly":
					record("重接前驱与后继，更新头尾和长度", [], 3)
				elif kind == "queue":
					record("更新 HEAD 和长度", [], 3)
		"update":
			_visit_to(index)
			items[index].value = value
			record("将位置 %d 修改为 %d" % [index + 1, value], [str(items[index].id)], 2)
		"get", "peek":
			if action == "peek":
				index = 0 if kind == "queue" else items.size() - 1
			_visit_to(index)
			record("查询结果：%s" % items[index].value, [str(items[index].id)], 3)
		"get_from_end":
			_get_from_end(index + 1)
		"reverse_range":
			_reverse_range(left, right)
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

func _remove_after(previous_index: int) -> void:
	var previous: Dictionary = items[previous_index]
	var target: Dictionary = _by_id(previous.next)
	previous.next = target.next
	if target.id == tail:
		tail = previous.id
	items.remove_at(previous_index + 1)

func _visit_to(index: int) -> void:
	if kind in ["linked", "doubly"]:
		var id := head
		for i in mini(index + 1, items.size()):
			record("沿 next 指针访问第 %d 个节点" % [i + 1], [str(id)], 1)
			id = _by_id(id).next
	elif index < items.size():
		record("定位到位置 %d" % [index + 1], [str(items[index].id)], 1)

func _get_from_end(k: int) -> void:
	var fast_id := head
	var slow_id := head
	for step in k:
		record("fast 沿 next 前进第 %d 步" % [step + 1], [str(fast_id)], 1)
		fast_id = _by_id(fast_id).next
	record("fast 已领先 slow %d 个节点" % k,
		[str(slow_id)] + ([str(fast_id)] if fast_id else []), 1)
	while fast_id:
		record("fast 与 slow 同步沿 next 前进",
			[str(slow_id), str(fast_id)], 1)
		fast_id = _by_id(fast_id).next
		slow_id = _by_id(slow_id).next
	var result: Dictionary = _by_id(slow_id)
	record("倒数第 %d 个节点是 %s" % [k, result.value], [str(slow_id)], 3)

func _reverse_range(left: int, right: int) -> void:
	if left > 0:
		_visit_to(left - 1)
	var original_ids: Array = items.map(func(item): return item.id)
	var pre_id: int = original_ids[left - 1] if left else 0
	var after_id: int = original_ids[right + 1] if right + 1 < original_ids.size() else 0
	reversal = {
		"phase": "save",
		"start": left,
		"end": right,
		"pre_id": pre_id,
		"after_id": after_id,
		"processed": [],
		"original_ids": original_ids,
		"pre_linked": false,
		"after_linked": false,
	}
	var pre_text := str(_by_id(pre_id).value) if pre_id else "NULL（由 HEAD 重连）"
	record("保存翻转区间前驱 pre：%s" % pre_text,
		[str(pre_id)] if pre_id else [], 1)
	var reversed_head := 0
	for offset in right - left + 1:
		var current: Dictionary = _by_id(original_ids[left + offset])
		current.next = reversed_head
		reversed_head = current.id
		reversal.processed.append(current.id)
		reversal.phase = "reverse"
		record("将节点 %s 移到下方，令其 next 指向已翻转链表" % current.value,
			[str(current.id)], 2)
	var new_tail_id: int = original_ids[left]
	reversal["new_head"] = reversed_head
	reversal["new_tail"] = new_tail_id
	if pre_id:
		_by_id(pre_id).next = reversed_head
	else:
		head = reversed_head
	reversal.pre_linked = true
	reversal.phase = "link_pre"
	record(("令 pre.next 指向翻转链表新头" if pre_id else
		"区间从首节点开始，令 HEAD 指向翻转链表新头"),
		[str(pre_id), str(reversed_head)] if pre_id else [str(reversed_head)], 3)
	_by_id(new_tail_id).next = after_id
	if not after_id:
		tail = new_tail_id
	reversal.after_linked = true
	reversal.phase = "link_after"
	record(("令翻转链表新尾 next 指向区间后继" if after_id else
		"区间到原链尾结束，令新尾 next 指向 NULL 并更新 TAIL"),
		[str(new_tail_id), str(after_id)] if after_id else [str(new_tail_id)], 3)
	var reordered: Array[Dictionary] = []
	for i in left:
		reordered.append(_by_id(original_ids[i]))
	for i in range(right, left - 1, -1):
		reordered.append(_by_id(original_ids[i]))
	for i in range(right + 1, original_ids.size()):
		reordered.append(_by_id(original_ids[i]))
	items = reordered
	reversal.clear()
	record("区间 [%d,%d] 翻转完成" % [left + 1, right + 1], [], 3)

func _grow() -> void:
	if kind != "dynamic_array" or items.size() < capacity:
		return
	var old := capacity
	migration = {"old_capacity": old, "new_capacity": old * 2, "copied": 0, "phase": "lift"}
	record("容量 %d 已满：将旧数组上移，准备迁移内存" % old, [], 0)
	migration.phase = "allocate"
	record("在下方申请 %d 个槽位的新内存，旧内存暂时保留" % [old * 2], [], 0)
	for i in items.size():
		record("读取旧内存 [%d]=%s，准备向下复制" % [i + 1, items[i].value], [str(items[i].id)], 1)
		migration.copied = i + 1
		migration.phase = "copy"
		record("将 %s 从旧内存 [%d] 向下复制到新内存 [%d]（%d/%d）" %
			[items[i].value, i + 1, i + 1, i + 1, items.size()], [str(items[i].id)], 2)
	capacity = old * 2
	migration.phase = "switch"
	record("全部元素已复制，数组指针切换到新内存，容量更新为 %d" % capacity, [], 3)
	migration.phase = "release"
	record("释放上方旧内存；新内存中的元素保持原顺序", [], 3)
	migration.clear()
	record("内存迁移完成；单次扩容 O(n)，append 均摊 O(1)", [], 3)

func _migration_view() -> Dictionary:
	var nodes: Array = []
	var annotations: Array = []
	var allocated: bool = migration.phase != "lift"
	var released: bool = migration.phase == "release"
	if not released:
		annotations.append({"pos": Vector2(46, 40),
			"text": "旧内存 · 容量 %d%s" % [migration.old_capacity,
				" · 待释放" if migration.phase == "switch" else " · 保留原数据"]})
	for i in items.size():
		var item := items[i]
		var x := 75.0 + i * 78
		# The stable element ID travels down. Its source copy remains until release.
		if allocated and not released:
			nodes.append(vertex("old_memory_%d" % item.id, item.value, x, 100,
				"[%d]" % [i + 1], "box"))
		nodes.append(vertex(item.id, item.value, x, 320 if i < migration.copied else 100,
			"[%d]" % [i + 1], "box"))
	if allocated:
		annotations.append({"pos": Vector2(46, 260),
			"text": "新内存 · 容量 %d · %s" % [migration.new_capacity,
				"当前数组" if migration.phase in ["switch", "release"] else
				"已复制 %d/%d" % [migration.copied, items.size()]]})
		for i in range(migration.copied, migration.new_capacity):
			nodes.append(vertex("empty%d" % i, "·", 75 + i * 78, 320,
				"[%d]" % [i + 1], "box", "muted"))
	return {"nodes": nodes, "edges": [], "annotations": annotations,
		"memory": migration.duplicate(), "stats": "长度 %d  /  容量 %d → %d  ·  内存迁移" %
			[items.size(), migration.old_capacity, migration.new_capacity]}

func _reversal_view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var annotations: Array = [
		{"pos": Vector2(32, 36), "text": "原链表"},
		{"pos": Vector2(32, 350), "text": "下方翻转链表"},
	]
	var original_ids: Array = reversal.original_ids
	var processed: Array = reversal.processed
	var processed_lookup := {}
	for id in processed:
		processed_lookup[id] = true
	var start: int = reversal.start
	var finish: int = reversal.end
	var segment_size := finish - start + 1
	var positions := {}
	for original_index in original_ids.size():
		var id: int = original_ids[original_index]
		var final_index := original_index
		var y := 200.0
		if processed_lookup.has(id):
			final_index = start + finish - original_index
			y = 410.0
		var x := 75.0 + final_index * 110.0
		positions[id] = Vector2(x, y)
		var item: Dictionary = _by_id(id)
		nodes.append(vertex(id, item.value, x, y, "[%d]" % [final_index + 1], "circle"))
	if processed.is_empty():
		for i in range(original_ids.size() - 1):
			edges.append(edge(original_ids[i], original_ids[i + 1], "next"))
	else:
		for i in range(start - 1):
			edges.append(edge(original_ids[i], original_ids[i + 1], "next"))
		var remaining_start := start + processed.size()
		for i in range(remaining_start, original_ids.size() - 1):
			edges.append(edge(original_ids[i], original_ids[i + 1], "next"))
		for i in range(processed.size() - 1, 0, -1):
			edges.append(edge(processed[i], processed[i - 1], "next"))
	var new_head_id: int = reversal.get("new_head", processed[-1] if not processed.is_empty() else 0)
	var new_tail_id: int = reversal.get("new_tail", processed[0] if not processed.is_empty() else 0)
	if reversal.pre_linked:
		if reversal.pre_id:
			edges.append(edge(reversal.pre_id, new_head_id, "next"))
		else:
			edges.append(edge("head_marker", new_head_id))
	if reversal.after_linked:
		edges.append(edge(new_tail_id,
			reversal.after_id if reversal.after_id else "next_null", "next"))
	elif not processed.is_empty():
		var temporary_null := vertex("reverse_null", "NULL",
			positions[processed[0]].x + 100.0, 410.0, "", "label")
		temporary_null["size"] = Vector2(62, 26)
		temporary_null["pickable"] = false
		nodes.append(temporary_null)
		edges.append(edge(processed[0], "reverse_null", "next"))
	var head_target: int = new_head_id if reversal.pre_linked and start == 0 else original_ids[0]
	var tail_target: int = new_tail_id if reversal.after_linked and finish == original_ids.size() - 1 else original_ids[-1]
	var tail_label := "原 TAIL" if finish == original_ids.size() - 1 and not reversal.after_linked else "TAIL"
	for marker in [
		{"id": "head_marker", "label": "HEAD", "target": head_target},
		{"id": "tail_marker", "label": tail_label, "target": tail_target},
	]:
		var target_pos: Vector2 = positions[marker.target]
		var marker_node := vertex(marker.id, marker.label, target_pos.x, target_pos.y - 100.0,
			"", "label")
		marker_node["size"] = Vector2(62, 26)
		marker_node["pickable"] = false
		nodes.append(marker_node)
		if marker.id == "tail_marker" or not reversal.pre_linked or start != 0:
			edges.append(edge(marker.id, marker.target))
	var show_main_null: bool = reversal.after_linked or finish < original_ids.size() - 1 or processed.is_empty()
	if show_main_null:
		var tail_pos: Vector2 = positions[tail_target]
		var next_null := vertex("next_null", "NULL", tail_pos.x + 110.0, tail_pos.y, "", "label")
		next_null["size"] = Vector2(62, 26)
		next_null["pickable"] = false
		nodes.append(next_null)
		if reversal.after_linked or finish < original_ids.size() - 1 or processed.is_empty():
			edges.append(edge(tail_target, "next_null", "next"))
	if reversal.pre_id:
		var pre_pos: Vector2 = positions[reversal.pre_id]
		var pre_marker := vertex("reverse_pre", "pre", pre_pos.x + 42.0, pre_pos.y - 100.0,
			"", "label")
		pre_marker["size"] = Vector2(46, 26)
		pre_marker["pickable"] = false
		nodes.append(pre_marker)
		edges.append(edge("reverse_pre", reversal.pre_id))
	else:
		var pre_null := vertex("reverse_pre", "pre = NULL", -20.0, 200.0, "", "label")
		pre_null["size"] = Vector2(86, 26)
		pre_null["pickable"] = false
		nodes.append(pre_null)
		annotations.append({"pos": Vector2(32, 268),
			"text": "i = 1：pre 为 NULL，稍后直接更新 HEAD"})
	return {
		"nodes": nodes,
		"edges": edges,
		"annotations": annotations,
		"reversal": reversal.duplicate(true),
		"stats": "长度 %d  ·  翻转 [%d,%d]  ·  下方已处理 %d/%d" %
			[items.size(), start + 1, finish + 1, processed.size(), segment_size],
	}

func view() -> Dictionary:
	if not migration.is_empty():
		return _migration_view()
	if not reversal.is_empty():
		return _reversal_view()
	var nodes: Array = []
	var edges: Array = []
	var outlines: Array = []
	var linked := kind in ["linked", "doubly"]
	var stack := kind == "stack"
	var occupied := {}
	for i in items.size():
		var item := items[i]
		var slot: int = visual_slots.get(item.id, i)
		occupied[slot] = true
		var x := 150.0 if stack else 75.0 + slot * (110.0 if linked else 78.0)
		var y := 660.0 - slot * 68.0 if stack else 200.0
		var detail := "[%d]" % [(i if stack else slot) + 1]
		if stack and i == items.size() - 1:
			detail += " TOP"
		if kind == "queue":
			if i == 0: detail += " HEAD"
			if i == items.size() - 1: detail += " TAIL"
		var node := vertex(item.id, item.value, x, y, detail, "circle" if linked else "box")
		if stack:
			node["detail_offset"] = Vector2(76, 5)
		nodes.append(node)
		if linked:
			if item.next: edges.append(edge(item.id, item.next, "next"))
			if kind == "doubly" and item.prev:
				edges.append(edge(item.id, item.prev, "prev", true))
	if linked and not items.is_empty():
		var first_x := 75.0
		var last_x := 75.0 + (items.size() - 1) * 110.0
		var head_x := first_x
		var tail_x := last_x
		if items.size() == 1:
			head_x -= 34.0
			tail_x += 34.0
		for marker in [
			{"id": "head_marker", "label": "HEAD", "x": head_x},
			{"id": "tail_marker", "label": "TAIL", "x": tail_x},
			{"id": "next_null", "label": "NULL", "x": last_x + 110.0},
		]:
			var marker_node := vertex(marker.id, marker.label, marker.x,
				100.0 if marker.id.ends_with("marker") else 200.0, "", "label")
			marker_node["size"] = Vector2(62, 26)
			marker_node["pickable"] = false
			nodes.append(marker_node)
		if kind == "doubly":
			var prev_null := vertex("prev_null", "NULL", first_x - 110.0, 200.0, "", "label")
			prev_null["size"] = Vector2(62, 26)
			prev_null["pickable"] = false
			nodes.append(prev_null)
		edges.append(edge("head_marker", head))
		edges.append(edge("tail_marker", tail))
		if kind == "doubly":
			edges.append(edge(head, "prev_null", "prev", true))
		edges.append(edge(tail, "next_null", "next"))
	if stack:
		var opening_y := 592.0 if items.is_empty() else 660.0 - (items.size() - 1) * 68.0 - 48.0
		outlines.append({"points": [
			Vector2(110, opening_y), Vector2(110, 698),
			Vector2(190, 698), Vector2(190, opening_y)
		], "width": 3.0})
	if kind in ["array", "dynamic_array"]:
		for i in capacity:
			if not occupied.has(i):
				nodes.append(vertex("empty%d" % i, "·", 75 + i * 78, 200, "[%d]" % [i + 1], "box", "muted"))
	var stats := "长度 %d" % items.size()
	if kind in ["array", "dynamic_array"]:
		stats += "  /  容量 %d" % capacity
	return {"nodes": nodes, "edges": edges, "outlines": outlines, "stats": stats}

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
