class_name HeapModel
extends LabModel

var items: Array = []
var sorted_from := -1
var result := 0
var max_heap := false
var source_items: Array = []
var filling := false

func _init(p_kind: String = "binary_heap") -> void:
	super(p_kind)
	code.assign(["将元素加入末尾 / 建立大顶堆", "与父节点比较，上浮",
		"交换堆顶与末尾，缩小堆", "选择更优的子节点，下沉", "堆序恢复 / 排序完成"])
	recording = false
	_build([12, 7, 24, 3, 16, 9])
	recording = true

func operations() -> Array:
	var sequence := field("values", "整数序列（最多 15 个）", "12,7,24,3,16,9", true)
	return [op("build", "构建最小堆", [sequence]),
		op("insert", "插入", [field("value", "数值", "5")]),
		op("extract", "提取最小值"), op("sort", "堆排序（升序）", [sequence])]

func _better(a: int, b: int) -> bool:
	return a > b if max_heap else a < b

func _build(values: Array) -> void:
	max_heap = false
	var elements: Array = []
	for value in values: elements.append({"id": uid(), "value": value})
	_fill_tree(elements)
	for i in range(items.size() / 2 - 1, -1, -1): _down(i, items.size())

func _fill_tree(elements: Array) -> void:
	sorted_from = -1
	source_items = elements.duplicate(true)
	items.clear()
	filling = true
	record("原数组已就绪；从空树开始，按层序逐个填入节点", [], 0)
	for i in source_items.size():
		items.append(source_items[i].duplicate())
		record("将 a[%d]=%d 填入完全二叉树的第 %d 个位置" %
			[i + 1, items[i].value, i + 1], [str(items[i].id)], 0)
	filling = false
	source_items.clear()
	record("节点已全部填入；现在从最后一个非叶节点开始下沉，建立%s" %
		("大顶堆" if max_heap else "最小堆"), [], 3)

func _swap(a: int, b: int) -> void:
	var temp: Dictionary = items[a]
	items[a] = items[b]
	items[b] = temp
	record("交换位置 %d 与 %d" % [a + 1, b + 1], [str(items[a].id), str(items[b].id)], 3)

func _down(index: int, count: int) -> void:
	calls.append("sift_down(%d, size=%d)" % [index + 1, count])
	while index * 2 + 1 < count:
		var child := index * 2 + 1
		if child + 1 < count and _better(items[child + 1].value, items[child].value): child += 1
		record("比较父节点与候选子节点", [str(items[index].id), str(items[child].id)], 3)
		if not _better(items[child].value, items[index].value): break
		_swap(index, child)
		index = child
	calls.pop_back()

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		var values := integers(args.values, 15)
		if not error.is_empty(): return false
		begin()
		_build(values)
	elif action == "insert":
		if items.size() >= 15: return fail("最多演示 15 个元素。")
		begin()
		sorted_from = -1
		max_heap = false
		items.append({"id": uid(), "value": int(args.value)})
		var i := items.size() - 1
		record("新元素放在末尾", [str(items[i].id)], 0)
		while i > 0:
			var parent := (i - 1) / 2
			record("比较当前元素与父节点", [str(items[i].id), str(items[parent].id)], 1)
			if not _better(items[i].value, items[parent].value): break
			_swap(i, parent)
			i = parent
	elif action == "extract":
		if items.is_empty(): return fail("空堆无法提取。")
		begin()
		sorted_from = -1
		max_heap = false
		result = items[0].value
		_swap(0, items.size() - 1)
		items.pop_back()
		record("移除最小值 %d；末尾元素补到根" % result, [], 2)
		_down(0, items.size())
	else:
		var elements: Array = items.duplicate(true)
		if args.has("values"):
			var values := integers(args.values, 15)
			if not error.is_empty(): return false
			elements.clear()
			for value in values: elements.append({"id": uid(), "value": value})
		begin()
		max_heap = true
		_fill_tree(elements)
		for i in range(items.size() / 2 - 1, -1, -1): _down(i, items.size())
		for end in range(items.size() - 1, 0, -1):
			_swap(0, end)
			sorted_from = end
			record("最大值归位到 [%d]，绿色部分已排序" % [end + 1], [str(items[end].id)], 2)
			_down(0, end)
		sorted_from = 0
		# An ascending array also satisfies min-heap order for later insert/extract.
		max_heap = false
	record("操作完成%s" % ("：升序排列" if action == "sort" else ""), [], 4)
	return true

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	for i in items.size():
		var depth := int(log(i + 1) / log(2))
		var first := (1 << depth) - 1
		var x := (i - first + 0.5) * 720.0 / (1 << depth)
		var tone := "green" if sorted_from >= 0 and i >= sorted_from else ""
		nodes.append(vertex(items[i].id, items[i].value, x, 65 + depth * 100, "[%d]" % [i + 1], "circle", tone))
		if i > 0: edges.append(edge(items[(i - 1) / 2].id, items[i].id))
	if filling:
		for i in source_items.size():
			var item: Dictionary = source_items[i]
			nodes.append(vertex("array" + str(item.id), item.value, 50 + i * 65, 480, "[%d]" % [i + 1], "box"))
			if i >= items.size():
				nodes.append(vertex(item.id, item.value, 50 + i * 65, 480, "", "box"))
	else:
		for i in items.size():
			var tone := "green" if sorted_from >= 0 and i >= sorted_from else ""
			nodes.append(vertex("array" + str(items[i].id), items[i].value, 50 + i * 65, 480,
				"[%d]" % [i + 1], "box", tone))
	var mode := "逐个入树 %d/%d" % [items.size(), source_items.size()] if filling else (
		"升序排列（可继续最小堆操作）" if sorted_from == 0 else ("大顶堆 → 升序" if max_heap else "最小堆"))
	return {"nodes": nodes, "edges": edges, "stats": "元素 %d · %s" % [items.size(), mode],
		"filling": filling, "annotations": [{"pos": Vector2(25, 420), "text": "原数组 · 按下标逐个入树" if filling else "数组存储"}]}

func invariant() -> String:
	var count := items.size() if sorted_from < 0 else sorted_from
	for i in range(1, count):
		if _better(items[i].value, items[(i - 1) / 2].value): return "heap order"
	if sorted_from >= 0:
		for i in range(maxi(sorted_from, 1), items.size()):
			if items[i - 1].value > items[i].value: return "sorted suffix"
	return ""
