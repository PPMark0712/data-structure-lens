class_name HashModel
extends LabModel

const SIZE := 11
var slots: Array = []
var buckets: Array = []

func _init(p_kind: String = "hash_linear") -> void:
	super(p_kind)
	code.assign(["h = ((key % 11) + 11) % 11 + 1", "探测槽 = (h−1+偏移) mod 11 + 1",
		"遇冲突继续；删除标记不能终止查找", "找到键或可用位置，返回结果"])
	slots.resize(SIZE)
	for i in SIZE:
		buckets.append([])
	recording = false
	for value in [12, 23, 7, 34]:
		perform("insert", {"value": value})
	recording = true
	frames.clear()

func operations() -> Array:
	var value := field("value", "键（整数）", "45")
	return [op("insert", "插入", [value]), op("find", "查找", [value]),
		op("delete", "删除", [value]), op("clear", "清空")]

func _hash(value: int) -> int:
	return posmod(value, SIZE)

func probe(value: int) -> Array[int]:
	var result: Array[int] = []
	for i in SIZE:
		var index := posmod(_hash(value) + (i * i if kind == "hash_quadratic" else i), SIZE)
		if not result.has(index):
			result.append(index)
	return result

func contains(value: int) -> bool:
	if kind == "hash_chain":
		return buckets[_hash(value)].has(value)
	for index in probe(value):
		if slots[index] == null:
			return false
		if slots[index] is int and slots[index] == value:
			return true
	return false

func perform(action: String, args: Dictionary) -> bool:
	var value := int(args.get("value", 0))
	if action == "insert" and contains(value):
		return fail("键 %d 已存在；本演示采用集合语义。" % value)
	if action == "insert" and kind == "hash_chain" and buckets[_hash(value)].size() >= 8:
		return fail("该桶已达演示上限 8 个节点。")
	begin()
	if action == "clear":
		slots.fill(null)
		for bucket in buckets: bucket.clear()
		record("清空所有槽位与删除标记", [], 3)
		return true
	var home := _hash(value)
	record("h(%d) = %d" % [value, home + 1], ["slot%d" % home], 0)
	if kind == "hash_chain":
		var bucket: Array = buckets[home]
		for i in bucket.size():
			var id := "key%d" % bucket[i]
			record("访问桶 %d 中的键 %d" % [home + 1, bucket[i]], [id], 1)
			if bucket[i] == value:
				if action == "delete":
					bucket.remove_at(i)
					record("断开连接，删除键 %d" % value, ["slot%d" % home], 3)
				else:
					record("找到键 %d" % value, [id], 3)
				return true
		if action == "insert":
			bucket.append(value)
			record("将键 %d 加入桶 %d 的链表" % [value, home + 1], ["key%d" % value], 3)
		else:
			record("键 %d 不存在" % value, [], 3)
		return true
	var first_free := -1
	for index in probe(value):
		var id := "slot%d" % index
		record("探测槽位 %d" % [index + 1], [id], 1)
		if slots[index] is int and slots[index] == value:
			if action == "delete":
				slots[index] = "DEL"
				record("标记 DEL，保留探测链连续性", [id], 2)
			else:
				record("找到键 %d，槽位 %d" % [value, index + 1], [id], 3)
			return true
		if slots[index] == null or slots[index] is String:
			if first_free == -1: first_free = index
			if slots[index] == null: break
		else:
			record("冲突：槽内是 %s，继续探测" % slots[index], [id], 2)
	if action == "insert":
		if first_free == -1:
			return fail("探测序列中没有空槽。二次探测不一定访问所有槽位。" if kind == "hash_quadratic" else "哈希表已满。")
		slots[first_free] = value
		record("将 %d 写入槽位 %d" % [value, first_free + 1], ["slot%d" % first_free], 3)
	else:
		record("键 %d 不存在" % value, [], 3)
	return true

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var count := 0
	for i in SIZE:
		var label: Variant = slots[i] if slots[i] != null else "·"
		if kind == "hash_chain": label = i + 1
		nodes.append(vertex("slot%d" % i, label, 70, 65 + i * 65, "h=%d" % [i + 1], "box",
			"muted" if label in ["·", "DEL"] else ""))
		if kind == "hash_chain":
			for j in buckets[i].size():
				var id := "key%d" % buckets[i][j]
				nodes.append(vertex(id, buckets[i][j], 230 + j * 95, 65 + i * 65))
				edges.append(edge("slot%d" % i if j == 0 else "key%d" % buckets[i][j - 1], id))
				count += 1
		elif slots[i] is int:
			count += 1
	return {"nodes": nodes, "edges": edges,
		"stats": "表长 11  ·  元素 %d  ·  负载 %.2f%s" % [count, float(count) / SIZE,
		"  ·  (h−1+i²) mod 11 + 1" if kind == "hash_quadratic" else ""]}

func invariant() -> String:
	for i in SIZE:
		if kind == "hash_chain":
			for value in buckets[i]:
				if _hash(value) != i: return "wrong bucket"
		elif slots[i] is int and not contains(slots[i]):
			return "broken probe chain"
	return ""
