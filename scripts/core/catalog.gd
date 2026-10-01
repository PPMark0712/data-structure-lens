class_name LabCatalog
extends RefCounted

const ENTRIES := [
	["线性结构", "array", "静态数组", "固定容量，按位置读写与移动元素", "linear"],
	["线性结构", "dynamic_array", "动态数组", "Append 与倍增扩容，观察复制成本", "linear"],
	["线性结构", "linked", "单向链表", "沿 next 访问、插入与断链", "linear"],
	["线性结构", "doubly", "双向链表", "观察 next / prev 两个方向的连接", "linear"],
	["线性结构", "stack", "栈", "后进先出 LIFO，观察 TOP", "linear"],
	["线性结构", "mono_stack", "单调栈", "逐个求左侧最近严格更大值的下标，栈顶朝右", "monotonic"],
	["线性结构", "queue", "队列", "先进先出 FIFO，观察 HEAD / TAIL", "linear"],
	["线性结构", "mono_queue", "单调队列", "固定窗口最大值下标，队首在左、队尾在右", "monotonic"],
	["哈希表", "hash_linear", "线性探测", "h+i，冲突探测与删除标记", "hash_table"],
	["哈希表", "hash_quadratic", "二次探测", "h+i²，有限探测序列与冲突", "hash_table"],
	["哈希表", "hash_chain", "链地址法", "每个哈希桶维护一条冲突链", "hash_table"],
	["区间结构", "fenwick", "一维树状数组", "lowbit 跳转，单点加与前缀和", "ranges"],
	["区间结构", "fenwick2", "二维树状数组", "双层 lowbit 跳转与矩形求和", "ranges"],
	["区间结构", "sparse_table", "ST 表", "幂次区间预处理，静态区间最小值", "ranges"],
	["区间结构", "segment", "Lazy 线段树", "区间加、区间和与标记下传", "segment"],
	["区间结构", "dynamic_segment", "动态开点线段树", "按需创建节点，单点加与区间和", "segment"],
	["区间结构", "segment2", "二维线段树", "外层行树、内层列树与矩形求和", "segment2"],
	["区间结构", "persistent_segment", "可持久化线段树", "路径复制、版本根与共享子树", "segment"],
	["堆", "binary_heap", "二叉堆", "最小堆，上浮、下沉与提取最小值", "heaps"],
	["堆", "heap_sort", "堆排序", "原地大顶堆建堆与逐轮排序", "heaps"],
	["堆", "binomial", "二项堆", "按度合并二项树，观察进位", "forest_heaps"],
	["堆", "fibonacci", "斐波那契堆", "根链表、合并、减键与级联切断", "forest_heaps"],
	["Trie", "trie", "字符串 Trie", "逐字符沿边，词频与前缀计数", "trie"],
	["Trie", "trie01", "01 Trie", "8 位非负整数，最大异或查询", "trie"],
	["Trie", "persistent_trie", "可持久化 01 Trie", "路径复制与历史版本最大异或", "trie"],
	["平衡树", "avl", "AVL 树", "高度、平衡因子与单双旋", "balanced"],
	["平衡树", "treap", "Treap", "BST 键序 + 固定种子随机优先级", "balanced"],
	["平衡树", "splay", "Splay 树", "Zig、Zig-Zig 与 Zig-Zag 伸展", "balanced"],
	["平衡树", "red_black", "红黑树", "颜色约束、旋转与插入删除修复", "red_black"],
	["动态树", "lct", "Link-Cut Tree", "动态森林连边 / 断边与路径聚合", "lct"],
]

static func create(entry: Array) -> LabModel:
	var path := "res://scripts/models/%s.gd" % entry[4]
	if not ResourceLoader.exists(path):
		return null
	return load(path).new(entry[1])
