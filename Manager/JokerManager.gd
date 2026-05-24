extends Node

"""小丑牌管理器（AutoLoad 单例）
管理玩家当前持有的小丑牌，并在各时机统一调度触发。
所有小丑牌效果均在 JokerCard 基类内根据 id 判断，无需外部子类。
"""

const JOKER_SCENE = preload("res://joker/Joker_card.tscn")
const MAX_JOKERS = 5

var owned_jokers: Array[JokerCard] = []
var joker_container: HBoxContainer = null

# 信号
signal joker_added(joker: JokerCard)
signal joker_removed(index: int)
signal jokers_changed

# ============================================================
# 持有管理
# ============================================================

func add_joker_by_id(id: int) -> JokerCard:
	"""通过 id 添加一张小丑牌到 joker_container，返回实例（超过上限返回 null）"""
	if owned_jokers.size() >= MAX_JOKERS:
		push_warning("小丑牌已满，无法添加")
		return null
	
	var joker = _create_joker(id)
	if joker == null:
		return null
	
	# 创建 Panel 卡槽并放入小丑牌
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(71.0, 95.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.self_modulate.a = 0
	if joker_container:
		joker_container.add_child(panel)
	joker.position = Vector2.ZERO
	panel.add_child(joker)
	
	owned_jokers.append(joker)
	joker_added.emit(joker)
	jokers_changed.emit()
	arrange_jokers()
	return joker

func add_joker_instance(joker: JokerCard) -> bool:
	"""直接添加一个小丑牌实例"""
	if owned_jokers.size() >= MAX_JOKERS:
		return false
	owned_jokers.append(joker)
	joker_added.emit(joker)
	jokers_changed.emit()
	return true

func remove_joker_at(index: int) -> void:
	"""移除指定索引的小丑牌及其 Panel 卡槽"""
	if index < 0 or index >= owned_jokers.size():
		return
	var joker = owned_jokers[index]
	var panel = joker.get_parent() as Panel
	owned_jokers.remove_at(index)
	joker_removed.emit(index)
	jokers_changed.emit()
	if panel:
		panel.queue_free()
	else:
		joker.queue_free()

func clear_jokers() -> void:
	"""清空所有小丑牌及其卡槽"""
	for joker in owned_jokers:
		var panel = joker.get_parent() as Panel
		if panel:
			panel.queue_free()
		else:
			joker.queue_free()
	owned_jokers.clear()
	jokers_changed.emit()

func get_owned_jokers() -> Array[JokerCard]:
	return owned_jokers.duplicate()

func has_space() -> bool:
	return owned_jokers.size() < MAX_JOKERS

# ============================================================
# 排列动画
# ============================================================

func arrange_jokers() -> void:
	"""排列小丑牌位置（确保小丑牌在各自卡槽内居中）"""
	if joker_container == null:
		return
	for panel in joker_container.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is JokerCard:
					if not child.has_dragged:
						var tween = create_tween()
						tween.set_ease(Tween.EASE_OUT)
						tween.set_trans(Tween.TRANS_BACK)
						tween.tween_property(child, "position", Vector2.ZERO, 0.3)
					break

# ============================================================
# 拖拽换位
# ============================================================

func try_drop_joker(joker: JokerCard) -> bool:
	"""尝试将拖拽的小丑牌插入到鼠标位置对应的卡槽，成功返回 true"""
	if joker_container == null:
		return false
	
	var mouse_pos = joker.get_global_mouse_position()
	var target_slot = _get_joker_slot_at_position(mouse_pos)
	
	# 如果鼠标不在任何 Panel 内，找 x 距离最近的 Panel
	if target_slot == null:
		target_slot = _get_nearest_joker_slot(mouse_pos)
	
	var source_slot = joker.get_parent() as Panel
	if target_slot == null or target_slot == source_slot:
		return false
	
	_insert_joker_to_slot(joker, source_slot, target_slot)
	return true

func _get_joker_slot_at_position(global_pos: Vector2) -> Panel:
	"""获取鼠标位置下的 Panel 卡槽"""
	if joker_container == null:
		return null
	for child in joker_container.get_children():
		if child is Panel:
			var rect = child.get_global_rect()
			if rect.has_point(global_pos):
				return child
	return null

func _get_nearest_joker_slot(global_pos: Vector2) -> Panel:
	"""获取 x 轴距离最近的 Panel 卡槽"""
	if joker_container == null:
		return null
	var nearest: Panel = null
	var min_dist = INF
	for child in joker_container.get_children():
		if child is Panel:
			var center_x = child.get_global_rect().get_center().x
			var dist = abs(global_pos.x - center_x)
			if dist < min_dist:
				min_dist = dist
				nearest = child
	return nearest

func _insert_joker_to_slot(joker: JokerCard, source_slot: Panel, target_slot: Panel):
	"""插入式移动：将 source_slot 移动到 target_slot 的位置，中间所有小丑牌自动移位"""
	var source_idx = source_slot.get_index()
	var target_idx = target_slot.get_index()
	if source_idx == target_idx:
		return
	
	# 收集所有小丑牌，记录它们当前的全局位置（用于动画）
	var affected_jokers: Array[JokerCard] = []
	var old_global_positions: Dictionary = {}
	for panel in joker_container.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is JokerCard:
					affected_jokers.append(child)
					old_global_positions[child] = child.global_position
					break
	
	# 移动 Panel 顺序（HBoxContainer 会自动重新排列其余 Panel）
	joker_container.move_child(source_slot, target_idx)
	
	# 恢复所有小丑牌的全局位置，避免 HBoxContainer 重排导致的跳变
	for j in affected_jokers:
		j.global_position = old_global_positions[j]
	
	# 动画：所有小丑牌平滑滑入各自新 Panel 的中心
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	for j in affected_jokers:
		tween.parallel()
		tween.tween_property(j, "position", Vector2.ZERO, 0.2)

# ============================================================
# 随机生成
# ============================================================

func add_random_joker() -> JokerCard:
	"""随机添加一张小丑牌（id 范围 0~159）"""
	var random_id = randi() % 10
	return add_joker_by_id(random_id)

func add_random_joker_from_pool(pool: Array[int]) -> JokerCard:
	"""从指定 id 池中随机抽取一张"""
	if pool.is_empty():
		return null
	var random_id = pool[randi() % pool.size()]
	return add_joker_by_id(random_id)

# ============================================================
# 统一触发
# ============================================================

func trigger_all(trigger_type: JokerCard.TriggerType, context: Dictionary = {}) -> Dictionary:
	"""触发所有拥有的小丑牌，汇总效果并返回 {chips, mult, money}"""
	var total = {"chips": 0, "mult": 0.0, "money": 0}
	
	for joker in owned_jokers:
		if joker.can_trigger(trigger_type, context):
			var result = joker.on_trigger(trigger_type, context)
			total["chips"] += result.get("chips", 0)
			total["mult"] += result.get("mult", 0.0)
			total["money"] += result.get("money", 0)
	
	# 将效果应用到 ScoreManager / MoneyManager
	if total["chips"] != 0:
		ScoreManager.add_chips(total["chips"])
	if total["mult"] != 0.0:
		ScoreManager.add_mult(total["mult"])
	if total["money"] != 0:
		MoneyManager.add_money(total["money"])
	
	return total

func get_independent_bonus() -> Dictionary:
	"""获取所有 INDEPENDENT 小丑牌的持续加成（用于 UI 显示或即时应用）"""
	var total = {"chips": 0, "mult": 0.0, "money": 0}
	for joker in owned_jokers:
		if joker.can_trigger(JokerCard.TriggerType.INDEPENDENT):
			var result = joker.on_trigger(JokerCard.TriggerType.INDEPENDENT, {})
			total["chips"] += result.get("chips", 0)
			total["mult"] += result.get("mult", 0.0)
			total["money"] += result.get("money", 0)
	return total

# ============================================================
# 内部方法
# ============================================================

func _create_joker(id: int) -> JokerCard:
	"""实例化小丑牌场景并初始化"""
	var joker = JOKER_SCENE.instantiate()
	joker.init_by_id(id)
	return joker
