# Elite Reward And Upgrade Effect System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加第一版精英怪生成与精英奖励掉落，并把现有“三选一选卡”重构成通用“三选一强化效果”系统。

**Architecture:** 精英怪由 `EnemyManager` 根据时间轴配置生成，但不压制普通刷怪，也不通过 `elite_defeated(reward_kind)` 直接发奖励。精英死亡继续走 `CombatEnemy.death_drop_entries` 掉落链路，掉落一个卡牌外观、不可吸附的拾取物；拾取后打开一个可配置奖励池驱动的“三选一强化效果”界面。现有升级选卡也迁移为 `add_card` 强化效果，后续“拾取卡牌 / 删除 / 调序 / 置换 / 强化”都共用同一套选项模型。

**Tech Stack:** Godot 4.6, GDScript, existing `EnemyManager`, `RunSpawnTimelineConfig`, `CombatEnemy`, `BattlePickup`, `PickupCollector`, `RunScene`, `CardRuntime`, `CardSelectUI`, `.tres` resources, Godot MCP Pro/headless test harness.

---

## 当前约束

- 精英怪暂时复用已有骷髅场景，通过变色和放大区分。
- 精英刷出时不暂停、不替代、不压制普通怪刷出。
- 精英死亡后不发 `elite_defeated(reward_kind)`，奖励只通过掉落物产生。
- 精英掉落使用普通怪已有的 `EnemyDropEntry` 配置机制。
- 精英奖励拾取物第一版表现为卡牌外观，且不能被 `PickupCollector` 的磁吸逻辑吸附。
- 精英奖励拾取后从奖励池中抽 3 个“强化效果”供玩家选择。
- 关键逻辑代码和每个新增方法都要写简洁中文注释。

## 文件结构

- Create `scripts/upgrades/upgrade_effect.gd`：三选一强化效果基类。
- Create `scripts/upgrades/add_card_upgrade_effect.gd`：拾取卡牌效果。
- Create `scripts/upgrades/remove_card_upgrade_effect.gd`：删除一张牌效果。
- Create `scripts/upgrades/reorder_deck_upgrade_effect.gd`：调序一次效果。
- Create `scripts/upgrades/replace_card_upgrade_effect.gd`：置换一次效果。
- Create `scripts/upgrades/grant_augment_upgrade_effect.gd`：直接强化效果。
- Create `scripts/upgrades/upgrade_offer_pool.gd`：可配置奖励池，负责按权重抽取 3 个效果。
- Modify `scripts/ui/card_select_ui.gd`：从只展示卡牌扩展为可展示强化效果。
- Modify `scripts/combat/run_scene.gd`：统一升级三选一和拾取物奖励三选一流程。
- Modify `scripts/combat/battle_pickup.gd`：增加是否允许磁吸的配置。
- Modify `scripts/combat/pickup_collector.gd`：尊重拾取物的磁吸开关。
- Create `scripts/combat/upgrade_offer_pickup_effect.gd`：拾取后打开强化效果三选一。
- Create `scenes/combat/EliteRewardCardPickup.tscn`：卡牌外观、不可吸附的精英奖励拾取物。
- Create `scripts/combat/elite_spawn_event.gd`：精英刷怪事件配置。
- Modify `scripts/combat/run_spawn_timeline_config.gd`：增加精英事件数组与按时间查询逻辑。
- Modify `scripts/combat/enemy_manager.gd`：按时间轴生成精英怪，普通刷怪照常运行。
- Modify `scripts/combat/enemy.gd`：支持配置精英外观、数值倍率和精英掉落。
- Modify `config/run_spawn_timeline_config.tres`：配置第一只精英怪。
- Create `config/upgrade_offer_pool_elite.tres`：精英奖励池。
- Create `config/upgrade_offer_pool_level_up.tres`：升级奖励池入口。
- Add tests under `tests/upgrades`, `tests/ui`, `tests/combat`。

---

## Task 1: 建立强化效果资源模型

**Files:**
- Create: `scripts/upgrades/upgrade_effect.gd`
- Create: `scripts/upgrades/add_card_upgrade_effect.gd`
- Create: `scripts/upgrades/remove_card_upgrade_effect.gd`
- Create: `scripts/upgrades/reorder_deck_upgrade_effect.gd`
- Create: `scripts/upgrades/replace_card_upgrade_effect.gd`
- Create: `scripts/upgrades/grant_augment_upgrade_effect.gd`
- Create: `tests/upgrades/test_upgrade_effects.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: 先写强化效果测试**

创建 `tests/upgrades/test_upgrade_effects.gd`，覆盖：

```gdscript
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const AddCardUpgradeEffectScript = preload("res://scripts/upgrades/add_card_upgrade_effect.gd")
const RemoveCardUpgradeEffectScript = preload("res://scripts/upgrades/remove_card_upgrade_effect.gd")
const GrantAugmentUpgradeEffectScript = preload("res://scripts/upgrades/grant_augment_upgrade_effect.gd")


## 验证加牌强化效果会向 CardRuntime 加入指定卡牌。
static func test_add_card_upgrade_effect_adds_configured_card() -> void:
	var runtime := CardRuntime.new()
	var card := CardResource.new(0, 7)
	var effect := AddCardUpgradeEffectScript.new()
	effect.card = card

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 1, "add-card effect adds one card")
	TestSupport.assert_eq(runtime.cards[0], card, "add-card effect inserts configured card")


## 验证删牌强化效果会删除预先写入的牌组下标。
static func test_remove_card_upgrade_effect_removes_selected_index() -> void:
	var runtime := CardRuntime.new()
	runtime.cards = [CardResource.new(0, 2), CardResource.new(1, 3), CardResource.new(2, 4)]
	var effect := RemoveCardUpgradeEffectScript.new()
	effect.selected_index = 1

	effect.apply_to_run(runtime, null, null)

	TestSupport.assert_eq(runtime.cards.size(), 2, "remove-card effect removes one card")
	TestSupport.assert_eq((runtime.cards[1] as CardResource).rank, 4, "remove-card effect removes selected slot")


## 验证直接强化效果会调用 RunScene 上配置的方法。
static func test_grant_augment_upgrade_effect_calls_run_scene_method() -> void:
	var effect := GrantAugmentUpgradeEffectScript.new()
	effect.method_name = "grant_global_permanent_volley_bonus"
	var receiver := _FakeRunScene.new()

	effect.apply_to_run(null, receiver, null)

	TestSupport.assert_eq(receiver.called_method, "grant_global_permanent_volley_bonus", "grant augment calls configured method")


class _FakeRunScene:
	extends RefCounted
	var called_method: String = ""

	func grant_global_permanent_volley_bonus() -> void:
		called_method = "grant_global_permanent_volley_bonus"
```

同时把 `res://tests/upgrades/test_upgrade_effects.gd` 加入 `tests/run_all_tests.gd`。

- [ ] **Step 2: 运行测试确认失败**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

预期：测试因为强化效果脚本不存在而失败。

- [ ] **Step 3: 实现 `UpgradeEffect` 基类**

`scripts/upgrades/upgrade_effect.gd`：

```gdscript
extends Resource
class_name UpgradeEffect
## 三选一强化效果基类：只定义展示信息、抽取权重和统一应用入口。

## 选项标题，显示在三选一按钮上。
@export var title: String = ""
## 选项说明，显示在标题下方。
@export var description: String = ""
## 抽取权重，数值越高越容易进入候选项。
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
## 是否需要先选择牌组中的一张牌作为目标。
@export var requires_deck_target: bool = false


## 判断该效果是否可进入奖励池。
func is_valid_effect() -> bool:
	return weight > 0.0 and not title.strip_edges().is_empty()


## 应用强化效果；子类覆盖这个方法执行实际效果。
func apply_to_run(_card_runtime: CardRuntime, _run_scene: Node, _card_pool: Node) -> void:
	pass
```

- [ ] **Step 4: 实现加牌效果**

`scripts/upgrades/add_card_upgrade_effect.gd`：

```gdscript
extends UpgradeEffect
class_name AddCardUpgradeEffect
## 加牌强化效果：把配置的卡加入当前牌组。

## 要加入的卡牌；为空时不产生效果。
@export var card: CardResource = null


## 将配置卡加入当前 CardRuntime，并可选通知 CardPool 消耗该卡。
func apply_to_run(card_runtime: CardRuntime, _run_scene: Node, card_pool: Node) -> void:
	if card_runtime == null or card == null:
		return
	card_runtime.add_card(card)
	if card_pool != null and card_pool.has_method("consume_card"):
		card_pool.call("consume_card", card)
```

- [ ] **Step 5: 实现删除、调序、置换、直接强化效果**

创建以下脚本，所有方法都带中文注释：

`remove_card_upgrade_effect.gd` 删除 `selected_index` 指向的牌；`reorder_deck_upgrade_effect.gd` 调用 `run_scene.open_hand_sort_reward()`；`replace_card_upgrade_effect.gd` 先删除 `selected_index`，再加入 `replacement_card`；`grant_augment_upgrade_effect.gd` 调用 `run_scene` 上白名单方法，第一版允许 `grant_global_permanent_volley_bonus`。

- [ ] **Step 6: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/upgrades tests/upgrades tests/run_all_tests.gd
git commit -m "feat: add upgrade effect resources"
```

---

## Task 2: 增加强化奖励池

**Files:**
- Create: `scripts/upgrades/upgrade_offer_pool.gd`
- Create: `config/upgrade_offer_pool_level_up.tres`
- Create: `config/upgrade_offer_pool_elite.tres`
- Modify: `scripts/combat/run_scene.gd`
- Modify: `tests/upgrades/test_upgrade_effects.gd`

- [ ] **Step 1: 增加奖励池抽取测试**

在 `tests/upgrades/test_upgrade_effects.gd` 增加测试：创建 3 个有效 `UpgradeEffect`，放入 `UpgradeOfferPool.effects`，调用 `roll_offer(3)` 后必须返回 3 个不重复效果。

- [ ] **Step 2: 实现 `UpgradeOfferPool`**

`scripts/upgrades/upgrade_offer_pool.gd` 负责：

```gdscript
extends Resource
class_name UpgradeOfferPool
## 三选一奖励池：从配置的强化效果里按权重抽取不重复选项。

## 候选强化效果数组，元素必须继承 UpgradeEffect。
@export var effects: Array[UpgradeEffect] = []


## 按权重抽取 count 个不重复强化效果。
func roll_offer(count: int = 3) -> Array[UpgradeEffect]:
	var source: Array[UpgradeEffect] = _valid_effects()
	var result: Array[UpgradeEffect] = []
	while result.size() < count and not source.is_empty():
		var picked := _pick_weighted(source)
		if picked == null:
			break
		result.append(picked)
		source.erase(picked)
	return result


## 收集当前可用的强化效果。
func _valid_effects() -> Array[UpgradeEffect]:
	var valid: Array[UpgradeEffect] = []
	for effect in effects:
		if effect != null and effect.is_valid_effect():
			valid.append(effect)
	return valid


## 从候选数组中按权重抽一个效果。
func _pick_weighted(valid: Array[UpgradeEffect]) -> UpgradeEffect:
	var total := 0.0
	for effect in valid:
		total += maxf(0.0, effect.weight)
	if total <= 0.0:
		return null
	var roll := randf() * total
	for effect in valid:
		roll -= maxf(0.0, effect.weight)
		if roll <= 0.0:
			return effect
	return valid.back()
```

- [ ] **Step 3: 在 `RunScene` 暴露奖励池配置**

增加：

```gdscript
## 升级时使用的三选一强化效果池；第一版升级仍主要生成加牌效果。
@export var level_up_upgrade_pool: UpgradeOfferPool = null
## 精英奖励拾取时使用的三选一强化效果池。
@export var elite_upgrade_pool: UpgradeOfferPool = null
```

- [ ] **Step 4: 创建第一版资源**

`config/upgrade_offer_pool_elite.tres` 包含：
- 删除一张：`RemoveCardUpgradeEffect`
- 调序一次：`ReorderDeckUpgradeEffect`
- 置换一次：`ReplaceCardUpgradeEffect`
- 强化一次：`GrantAugmentUpgradeEffect(method_name="grant_global_permanent_volley_bonus")`

`config/upgrade_offer_pool_level_up.tres` 先作为升级奖励池入口；升级时的加牌效果由 `RunScene` 根据当前抽到的卡动态包装。

- [ ] **Step 5: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/upgrades/upgrade_offer_pool.gd config/upgrade_offer_pool_level_up.tres config/upgrade_offer_pool_elite.tres scripts/combat/run_scene.gd tests/upgrades/test_upgrade_effects.gd
git commit -m "feat: add upgrade offer pools"
```

---

## Task 3: 把三选一 UI 从卡牌解耦为强化效果

**Files:**
- Modify: `scripts/ui/card_select_ui.gd`
- Modify: `scripts/combat/run_scene.gd`
- Create: `tests/ui/test_upgrade_offer_flow.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: 增加强化效果选择流程测试**

`tests/ui/test_upgrade_offer_flow.gd` 验证选择 `GrantAugmentUpgradeEffect` 后，会调用 `RunScene.grant_global_permanent_volley_bonus()`。

- [ ] **Step 2: 扩展 `CardSelectUI`**

增加信号：

```gdscript
signal upgrade_effect_selected(effect: Resource)
```

增加方法：

```gdscript
## 展示强化效果三选一；按钮内容来自效果标题和说明，不再要求数据是 CardResource。
func show_upgrade_effects(effects: Array) -> void:
	visible = true
	disable_selection()
	for i in range(_card_buttons.size()):
		var button: Button = _card_buttons[i]
		var has_effect := i < effects.size()
		button.visible = has_effect
		button.disabled = not has_effect
		if not has_effect:
			continue
		var effect: Resource = effects[i]
		button.text = "%s\n%s" % [str(effect.get("title")), str(effect.get("description"))]
		button.pressed.connect(func() -> void:
			emit_signal("upgrade_effect_selected", effect)
		, CONNECT_ONE_SHOT)
```

实现时按现有按钮字段名微调，但保留旧的 `show_cards()` 路径，避免一次性破坏现有测试。

- [ ] **Step 3: 在 `RunScene` 增加通用强化三选一流程**

新增 `_begin_upgrade_effect_offer(pool, title)`、`_on_upgrade_effect_selected(effect)`、`_apply_upgrade_effect_and_resume(effect)`、`_resume_after_upgrade_effect_offer()`。这些方法复用当前升级选卡的暂停、隐藏 HUD、恢复战斗逻辑；所有方法写中文注释。

- [ ] **Step 4: 处理需要牌组目标的效果**

如果 `effect.requires_deck_target == true`，先进入已有的牌组选择/调序 UI，选中牌后把 `selected_index` 写入效果，再调用 `_apply_upgrade_effect_and_resume(effect)`。

- [ ] **Step 5: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/ui/card_select_ui.gd scripts/combat/run_scene.gd tests/ui/test_upgrade_offer_flow.gd tests/run_all_tests.gd
git commit -m "refactor: support upgrade effect offers"
```

---

## Task 4: 把升级选卡迁移为加牌强化效果

**Files:**
- Modify: `scripts/combat/run_scene.gd`
- Modify: `scripts/upgrades/add_card_upgrade_effect.gd`
- Modify: `tests/ui/test_upgrade_offer_flow.gd`

- [ ] **Step 1: 增加卡牌转强化效果方法**

在 `RunScene` 增加：

```gdscript
## 将抽到的候选卡包装成加牌强化效果，让升级三选一也走统一效果流程。
func _cards_to_add_card_effects(cards: Array) -> Array:
	var effects: Array = []
	for card in cards:
		if not card is CardResource:
			continue
		var effect := AddCardUpgradeEffect.new()
		effect.card = card
		effect.title = "拾取 %s" % card.get_full_name()
		effect.description = "加入当前牌组"
		effects.append(effect)
	return effects
```

- [ ] **Step 2: 替换升级展示入口**

在升级抽到 `random_cards` 后，不再直接 `show_cards(random_cards)`，改为：

```gdscript
_current_upgrade_offer = _cards_to_add_card_effects(random_cards)
card_select_ui.show_upgrade_effects(_current_upgrade_offer)
```

- [ ] **Step 3: 保留旧方法兼容测试**

保留 `_complete_level_up_card(card)` 和 `show_cards()`，但主流程走 `_on_upgrade_effect_selected()`。这样现有测试和任何旧调用不会在这一阶段被硬切断。

- [ ] **Step 4: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/combat/run_scene.gd scripts/upgrades/add_card_upgrade_effect.gd tests/ui/test_upgrade_offer_flow.gd
git commit -m "refactor: express level-up choices as upgrade effects"
```

---

## Task 5: 增加不可吸附的精英奖励拾取物

**Files:**
- Modify: `scripts/combat/battle_pickup.gd`
- Modify: `scripts/combat/pickup_collector.gd`
- Create: `scripts/combat/upgrade_offer_pickup_effect.gd`
- Create: `scenes/combat/EliteRewardCardPickup.tscn`
- Create: `tests/combat/test_pickup_magnet_rules.gd`
- Modify: `tests/run_all_tests.gd`

- [ ] **Step 1: 增加不可吸附拾取物测试**

测试 `BattlePickup.magnet_enabled = false` 时，`can_be_magnetized()` 返回 `false`。

- [ ] **Step 2: 在 `BattlePickup` 增加磁吸开关**

```gdscript
## 是否允许被 PickupCollector 磁吸；精英奖励卡牌拾取物为 false。
@export var magnet_enabled: bool = true


## 返回本拾取物是否允许远距离磁吸。
func can_be_magnetized() -> bool:
	return magnet_enabled
```

- [ ] **Step 3: 修改 `PickupCollector`**

如果拾取物 `can_be_magnetized() == false` 且距离大于直接拾取距离，则跳过磁吸移动；距离进入直接拾取范围后仍允许拾取。

- [ ] **Step 4: 实现 `UpgradeOfferPickupEffect`**

```gdscript
extends PickupEffectConfig
class_name UpgradeOfferPickupEffect
## 拾取后打开强化效果三选一的拾取物效果。

## 奖励池；为空时不打开选择界面。
@export var offer_pool: UpgradeOfferPool = null
## 三选一标题。
@export var offer_title: String = "选择奖励"


## 拾取时请求当前 RunScene 打开奖励三选一。
func apply(player: CombatPlayer) -> void:
	if player == null:
		return
	var scene := player.get_tree().current_scene
	if scene != null and scene.has_method("begin_pickup_upgrade_offer"):
		scene.call("begin_pickup_upgrade_offer", offer_pool, offer_title)
```

- [ ] **Step 5: 在 `RunScene` 暴露拾取入口**

```gdscript
## 拾取物入口：打开指定奖励池的强化效果三选一。
func begin_pickup_upgrade_offer(pool: UpgradeOfferPool, title: String) -> void:
	_begin_upgrade_effect_offer(pool, title)
```

- [ ] **Step 6: 创建 `EliteRewardCardPickup.tscn`**

根节点使用 `BattlePickup`，设置：
- `magnet_enabled = false`
- `effect = UpgradeOfferPickupEffect`
- `offer_pool = config/upgrade_offer_pool_elite.tres`
- 外观第一版用简单卡牌形状/标签表达，后续可替换美术预制体。

- [ ] **Step 7: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/combat/battle_pickup.gd scripts/combat/pickup_collector.gd scripts/combat/upgrade_offer_pickup_effect.gd scenes/combat/EliteRewardCardPickup.tscn tests/combat/test_pickup_magnet_rules.gd tests/run_all_tests.gd
git commit -m "feat: add elite reward pickup"
```

---

## Task 6: 按时间轴生成精英骷髅

**Files:**
- Create: `scripts/combat/elite_spawn_event.gd`
- Modify: `scripts/combat/run_spawn_timeline_config.gd`
- Modify: `scripts/combat/enemy_manager.gd`
- Modify: `scripts/combat/enemy.gd`
- Modify: `config/run_spawn_timeline_config.tres`
- Modify: `tests/combat/test_spawn_director.gd`

- [ ] **Step 1: 增加精英事件测试**

测试 `RunSpawnTimelineConfig.elite_event_for_time(match_seconds, triggered)`：
- 触发时间前返回 `null`
- 到达触发时间返回事件资源
- 事件已记录在 `triggered` 中后返回 `null`

- [ ] **Step 2: 实现 `EliteSpawnEvent`**

```gdscript
extends Resource
class_name EliteSpawnEvent
## 精英刷怪事件：在指定时间生成一个复用普通敌人场景的精英版本。

## 局内经过秒数达到该值时触发。
@export var trigger_seconds: float = 150.0
## 精英敌人场景；为空时回落到 EnemyManager.enemy_scene。
@export var elite_scene: PackedScene = null
## 死亡掉落条目，沿用普通敌人的 EnemyDropEntry 机制。
@export var death_drop_entries: Array[EnemyDropEntry] = []
## 精英外观缩放倍率。
@export_range(1.0, 5.0, 0.05) var visual_scale_multiplier: float = 1.35
## 精英颜色调制。
@export var elite_modulate: Color = Color(1.45, 0.65, 0.25, 1.0)
## 精英生命倍率。
@export_range(1.0, 20.0, 0.1) var health_multiplier: float = 4.0
## 精英移动速度倍率。
@export_range(0.1, 5.0, 0.1) var move_speed_multiplier: float = 1.1
## 精英接触伤害倍率。
@export_range(0.1, 10.0, 0.1) var touch_damage_multiplier: float = 1.5


## 返回该事件是否可参与触发。
func is_valid_event() -> bool:
	return trigger_seconds >= 0.0
```

- [ ] **Step 3: 扩展 `RunSpawnTimelineConfig`**

增加：
- `@export var elite_events: Array[EliteSpawnEvent] = []`
- `elite_event_for_time(match_seconds: float, triggered: Dictionary) -> EliteSpawnEvent`

方法按 `trigger_seconds` 找到第一个到点且未触发的有效事件。

- [ ] **Step 4: 修改 `EnemyManager`**

在时间轴更新中检查精英事件：

```gdscript
## 返回当前时间可触发的精英事件。
func pending_elite_event_for_time(match_seconds: float) -> Resource:
	if not _has_valid_spawn_timeline():
		return null
	return spawn_timeline_config.elite_event_for_time(match_seconds, _triggered_elite_event_seconds)


## 标记精英事件已触发，避免同一时间点重复生成。
func mark_elite_event_triggered_from_event(event: Resource) -> void:
	if event == null:
		return
	_triggered_elite_event_seconds[float(event.trigger_seconds)] = true


## 生成精英敌人；该流程不会暂停或压制普通刷怪。
func _spawn_elite_from_event(event: Resource) -> void:
	var packed_scene: PackedScene = event.elite_scene
	if packed_scene == null:
		packed_scene = enemy_scene
	if packed_scene == null:
		return
	var enemy := packed_scene.instantiate()
	enemy.global_position = _pick_spawn_world_position()
	if enemy is CombatEnemy:
		var combat_enemy := enemy as CombatEnemy
		combat_enemy.target = resolve_spawn_target()
		combat_enemy.configure_as_elite(
			event.visual_scale_multiplier,
			event.elite_modulate,
			event.health_multiplier,
			event.move_speed_multiplier,
			event.touch_damage_multiplier,
			event.death_drop_entries
		)
	get_units_root().add_child(enemy)
```

在 `_update_timeline_state()` 里调用 `_spawn_elite_from_event()`，但不要修改普通刷怪计时器、预算或批次。

- [ ] **Step 5: 修改 `CombatEnemy`**

增加：
- `is_elite`
- `configure_as_elite(...)`
- `_apply_elite_config()`

`_ready()` 中应用：
- `scale *= visual_scale_multiplier`
- `modulate = elite_modulate`
- `move_speed *= move_speed_multiplier`
- `touch_damage *= touch_damage_multiplier`
- `death_drop_entries = elite_death_drop_entries`
- 生命倍率通过现有生命组件 setter 或新增 `set_enemy_max_health(value, refill)` 应用。

不新增 `elite_defeated` 信号，不在死亡时走特殊奖励逻辑。

- [ ] **Step 6: 配置第一只精英**

在 `config/run_spawn_timeline_config.tres` 增加一个 `EliteSpawnEvent`：
- `trigger_seconds = 150.0`
- `elite_scene =` 现有骷髅场景
- `death_drop_entries = [EnemyDropEntry(pickup_scene=EliteRewardCardPickup.tscn, drop_probability=1.0)]`
- `visual_scale_multiplier = 1.35`
- `elite_modulate =` 橙金色
- `health_multiplier = 4.0`
- `move_speed_multiplier = 1.1`
- `touch_damage_multiplier = 1.5`

- [ ] **Step 7: 运行测试并提交**

```powershell
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
git add scripts/combat/elite_spawn_event.gd scripts/combat/run_spawn_timeline_config.gd scripts/combat/enemy_manager.gd scripts/combat/enemy.gd config/run_spawn_timeline_config.tres tests/combat/test_spawn_director.gd
git commit -m "feat: spawn elite skeleton drops"
```

---

## Task 7: 文档和实机验证

**Files:**
- Modify: `docs/测试与进度.md`
- Modify: `docs/superpowers/plans/2026-04-30-elite-reward-system.md`

- [ ] **Step 1: 更新 T009 进度说明**

把 T009 更新为：

```markdown
- [ ] T009 精英奖励：删除牌 / 调序等奖励（第一阶段：时间轴精英 + 卡牌外观奖励掉落 + 强化效果三选一；精英词缀、遗物碎片、Boss 奖励后续实现）
```

- [ ] **Step 2: 增加快测说明**

写明：
- 精英事件配置在 `config/run_spawn_timeline_config.tres` 的 `elite_events`
- 第一版精英复用骷髅，靠放大和变色区分
- 死亡后通过 `death_drop_entries` 掉落不可吸附卡牌奖励
- 拾取后打开 `config/upgrade_offer_pool_elite.tres` 驱动的强化效果三选一

- [ ] **Step 3: 运行验证**

```powershell
git diff --check
& 'F:\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tests/run_all_tests.gd
```

如果 Godot MCP Pro 已连接，再执行：
- reload project
- 运行主场景
- 临时把精英触发时间调低
- 击杀精英
- 确认普通怪仍正常生成
- 确认精英掉落不可吸附，靠近后可拾取
- 确认拾取后打开强化效果三选一

- [ ] **Step 4: 提交文档**

```powershell
git add docs/测试与进度.md docs/superpowers/plans/2026-04-30-elite-reward-system.md
git commit -m "docs: document elite reward flow"
```

---

## 验收标准

- 精英刷新节奏在 `config/run_spawn_timeline_config.tres` 配置。
- 精英生成不压制普通刷怪。
- 精英复用骷髅模型，通过放大和调色区分。
- 精英死亡沿用普通 `death_drop_entries`，不发 `elite_defeated(reward_kind)`。
- 精英奖励拾取物表现为卡牌，不能被磁吸，但靠近可拾取。
- 拾取精英奖励后打开三选一，选项来自 `UpgradeOfferPool`。
- 升级选卡也被表示为 `AddCardUpgradeEffect`。
- 删除、调序、置换、强化均能作为强化效果进入奖励池。
- 新增关键逻辑和新增方法都有简洁中文注释。

## 后续阶段

- 精英词缀系统。
- 多种精英模型和技能。
- 遗物奖励表。
- Boss 实体与 Boss 奖励节奏。
- 更完整的卡牌强化、删牌、置换交互 UI。
