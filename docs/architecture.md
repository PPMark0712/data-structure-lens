# 数据结构实验室：实现约定

## 技术与范围

- Godot 4.7.2，Compatibility 渲染，GDScript，单线程 Web 导出。
- 全部计算在客户端执行；GitHub Pages 与本地 HTTP 服务均不需要后端。
- 原始需求见 `plan.md`。其中 ACL 按 AVL 实现；动态树选 Link-Cut Tree。
- 教育用小数据集，各结构明确限制容量、索引范围和操作语义。
- 米黄底 `#fdf6e3`、黑色字与连线；临时访问高亮浅蓝色。
- 中文字体为 Noto Sans SC 的静态 400 字重实例；许可证 `assets/OFL.txt`。

## 模型与快照

`scripts/core/model.gd` 中的 `LabModel` 继承 `RefCounted`，不引用场景节点。

- `operations()` 返回操作与字段定义；字段含 key、title、initial、text。
- `perform(action, args)` 验证参数，执行算法；失败返回 false 并设置 error。
- `begin()` 清空轨迹、记录操作前状态。
- `record(message, active_ids, code_line)` 深复制 `view()`，记录算法行号和调用栈。
- `view()` 返回 nodes、edges、stats；节点含稳定 id、label、pos、detail、shape、tone。
- `invariant()` 返回空字符串表示成立，否则返回错误说明。
- 算法每次改变逻辑关系后显式记录关键步骤，保证访问、比较、旋转、下传与回溯可见。
- `recording=false` 用于快速差分验证，不能影响算法结果。

快照只含值类型、数组和字典，不持有可变对象引用。算法可以先算完；画面由快照逐步追赶。图中的瞬时位置不参与算法计算。

## 播放与交互

`scripts/main.gd` 负责结构目录、动态参数表、严格整数验证、模型校验、操作级撤销和轨迹播放。

`scripts/ui/canvas.gd` 按稳定 ID 在快照间插值位置、淡入淡出节点与连边；支持缩放、平移、适应视图和节点选择。读取动画帧独立于模型当前状态。

- 播放过程中或停在历史步骤时，修改操作禁用；跳到末尾后可继续修改。
- 单步、进度条和回放只改变视觉游标；撤销恢复操作前模型。
- 无效输入显示具体错误，不静默失败。
- 模型操作失败或不变量失败时，界面恢复执行前保存的状态。
- 每个模块提供默认示例；恢复默认会清除历史。
- 递归调用栈是算法主动记录的教学轨迹，并非引擎调试堆栈。

## 验证

`tests/test_models.gd` 是无额外插件的 GDScript headless runner：

1. 各目录模块的默认状态、默认操作及轨迹完整性。
2. 每帧 ID 唯一、坐标有效、连边端点存在。
3. 固定种子随机操作，对照数组、集合或暴力求和。
4. 各模型的结构不变量；可持久化结构旧版本保持不变。

运行：

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_models.gd
```

隔离环境可复制 Godot 可执行文件到 `.tools/godot`，并在同目录创建 `_sc_` 以保存编辑器配置。`--log-file` 必须传入项目内的**绝对路径**，防止编辑器将相对日志路径解释为 `user://`。

## 版本策略

使用本仓库 Git 配置的 PPMark0712 / 939051420@qq.com。每个通过验证的功能阶段独立提交，不自动推送到远端。`.godot`、`.tools`、导出产物与测试截图不提交。
