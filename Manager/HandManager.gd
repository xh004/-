# hand_manager.gd（不需要 @onready 引用了！）
extends Node

const CARD_SCENE = preload("res://card/Poker_card.tscn")
const HAND_START_X =450.0
const HAND_Y = 500.0
const CARD_SPACING = 90.0

func _ready():
	"""节点就绪"""
	# 直接调用单例，无需获取节点
	print("剩余牌: ", DeckManager.get_remaining())

func draw_eight_cards(thedesk: HBoxContainer):
	"""抽取8张卡牌作为初始手牌"""
	self.desk = thedesk
	draw_cards(8, thedesk)

func draw_cards(count: int, thedesk: HBoxContainer):
	"""连续抽取指定数量的卡牌"""
	self.desk = thedesk
	for i in count:
		draw_one_card(thedesk)
	print("剩余牌: ", DeckManager.get_remaining())

func draw_one_card(thedesk: HBoxContainer):
	"""从牌堆抽取一张卡牌并加入当前手牌区"""
	self.desk = thedesk
	var data = DeckManager.draw_card()
	if data.is_empty():
		return
	
	var card = CARD_SCENE.instantiate()
	card.suit = data.suit
	card.rank = data.rank
	card.seal = data.seal
	card.enhancement = data.enhancement
	
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(71.0, 95.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.self_modulate.a = 0
	thedesk.add_child(panel)
	card.position = Vector2.ZERO
	panel.add_child(card)
	register_card(card)
	arrange_hand()

signal cards_played(cards: Array[PlayingCard])
signal cards_discarded(cards: Array[PlayingCard])
signal hand_changed
signal hand_scored(hand_type: String, chips: int, mult: float, score: int, cards: Array[PlayingCard])
signal plays_changed(value: int)
signal discards_changed(value: int)  

var hand_cards: Array[PlayingCard] = []
var selected_cards: Array[PlayingCard] = []
var ordered_hand_cards: Array[PlayingCard] = []  # 按屏幕从左到右顺序记录的手牌

var plays_left: int = 4
var discards_left: int = 4
var desk: HBoxContainer = null

func register_card(card: PlayingCard):
	"""注册卡牌到管理器"""
	hand_cards.append(card)
	card.state_changed.connect(_on_card_state_changed)
	card.play_value_revealed.connect(_on_play_value_revealed)

func _on_card_state_changed(new_state: PlayingCard.CardState, card: PlayingCard):
	"""状态变化时更新选中列表"""
	match new_state:
		PlayingCard.CardState.SELECTED:
			if not card in selected_cards:
				selected_cards.append(card)
		PlayingCard.CardState.NORMAL:
			selected_cards.erase(card)
		PlayingCard.CardState.PLAYED:
			selected_cards.erase(card)
			hand_cards.erase(card)
			ordered_hand_cards.erase(card)
		PlayingCard.CardState.DISCARDED:
			selected_cards.erase(card)
			hand_cards.erase(card)
			ordered_hand_cards.erase(card)

func get_selected_cards() -> Array[PlayingCard]:
	"""获取当前选中的卡牌"""
	selected_cards = selected_cards.filter(
		func(c): return c.state == PlayingCard.CardState.SELECTED
	)
	return selected_cards.duplicate()

func arrange_hand():
	"""排列手牌位置（确保卡牌在各自卡槽内居中）"""
	if desk == null:
		return
	
	for panel in desk.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is PlayingCard and child.state != PlayingCard.CardState.PLAYED and child.state != PlayingCard.CardState.DISCARDED:
					if child.state != PlayingCard.CardState.DRAGGING:
						var tween = create_tween()
						tween.set_ease(Tween.EASE_OUT)
						tween.set_trans(Tween.TRANS_BACK)
						tween.tween_property(child, "position", Vector2.ZERO, 0.3)
					break
	
	_update_ordered_hand_cards()

func sort_hand_by_colour():
	"""按花色和点数排序手牌，并带动画交换位置"""
	var cards = _get_active_cards()
	cards.sort_custom(_compare_cards)
	
	# 根据排序后的卡牌顺序，重新排列 Panel 在 desk 中的顺序
	for i in range(cards.size()):
		var card = cards[i]
		var panel = card.get_parent() as Panel
		if panel and desk:
			desk.move_child(panel, i)
	
	hand_cards = cards.duplicate()
	_update_ordered_hand_cards()

func sort_hand_by_rank():
	"""只按点数排序手牌，并带动画交换位置"""
	var cards = _get_active_cards()
	cards.sort_custom(_compare_cards_by_rank)
	
	for i in range(cards.size()):
		var card = cards[i]
		var panel = card.get_parent() as Panel
		if panel and desk:
			desk.move_child(panel, i)
	
	hand_cards = cards.duplicate()
	_update_ordered_hand_cards()

func _compare_cards(a: PlayingCard, b: PlayingCard) -> bool:
	"""排序比较器：先按花色，再按点数"""
	const SUIT_ORDER = { "Spade": 0, "Heart": 1, "Club": 2, "Diamond": 3 }
	const RANK_ORDER = { "2": 0, "3": 1, "4": 2, "5": 3, "6": 4, "7": 5, "8": 6, "9": 7, "10": 8, "J": 9, "Q": 10, "K": 11, "A": 12 }
	
	var suit_a = SUIT_ORDER.get(a.get_suit(), 999)
	var suit_b = SUIT_ORDER.get(b.get_suit(), 999)
	if suit_a != suit_b:
		return suit_a < suit_b
	
	var rank_a = RANK_ORDER.get(a.get_rank(), 999)
	var rank_b = RANK_ORDER.get(b.get_rank(), 999)
	return rank_a < rank_b

func _compare_cards_by_rank(a: PlayingCard, b: PlayingCard) -> bool:
	"""排序比较器：只按点数"""
	const RANK_ORDER = { "2": 0, "3": 1, "4": 2, "5": 3, "6": 4, "7": 5, "8": 6, "9": 7, "10": 8, "J": 9, "Q": 10, "K": 11, "A": 12 }
	
	var rank_a = RANK_ORDER.get(a.get_rank(), 999)
	var rank_b = RANK_ORDER.get(b.get_rank(), 999)
	return rank_a < rank_b

func reset_plays_and_discards(plays: int = 4, discards: int = 4):
	"""重置出牌和弃牌次数"""
	plays_left = plays
	discards_left = discards
	plays_changed.emit(plays_left)
	discards_changed.emit(discards_left)

func play_selected_cards() -> bool:
	"""打出选中的卡牌"""
	if plays_left <= 0:
		print("本回合出牌次数已用尽！")
		return false
	
	var to_play = get_selected_cards()
	
	if to_play.is_empty():
		print("没有选中的卡牌！")
		return false
	
	# 验证牌型（至少1张，最多5张）
	if to_play.size() > 5:
		print("最多选择5张")
		return false
	
	# 输出出的卡牌
	var card_names = to_play.map(func(c): return c.get_card_name())
	print("打出卡牌: ", card_names)
	cards_played.emit(to_play)
	
	# 第一步：标记为已打出，并同时上移
	for card in to_play:
		card.mark_as_played()
	
	var move_up_tween = create_tween()
	move_up_tween.set_ease(Tween.EASE_OUT)
	move_up_tween.set_trans(Tween.TRANS_QUAD)
	for card in to_play:
		move_up_tween.parallel()
		move_up_tween.tween_property(card, "global_position", card.global_position + Vector2(0, -80), 0.2)
	
	await move_up_tween.finished
	
	# 第二步：牌型计算
	var hand_type = ScoreManager.evaluate_hand(to_play)
	ScoreManager.set_hand_type(hand_type)
	ScoreManager.record_hand_type(hand_type)
	ScoreManager.record_cards_played(to_play.size())
	
	# 触发持续生效的小丑牌（INDEPENDENT）
	JokerManager.trigger_all(JokerCard.TriggerType.INDEPENDENT)
	
	# 触发出牌时小丑牌（ON_HAND_PLAYED）
	JokerManager.trigger_all(JokerCard.TriggerType.ON_HAND_PLAYED, {
		"played_cards": to_play,
		"hand_type": hand_type
	})
	
	# 只累加计分牌的 value 到筹码
	var scoring_cards = ScoreManager.get_scoring_cards(to_play, hand_type)
	
	# 按场景中的 x 位置从左到右排序
	scoring_cards.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
	# 第三步：只有计分卡牌才跳跃、积分，并触发 seal / enhancement 效果
	var pending_chips = 0
	var pending_mult = 0
	
	for card in scoring_cards:
		var jump_tween = card.score_jump()
		if jump_tween:
			await jump_tween.finished
		
		# 触发计分时小丑牌（ON_CARD_SCORED）
		JokerManager.trigger_all(JokerCard.TriggerType.ON_CARD_SCORED, {
			"scoring_card": card,
			"hand_type": hand_type
		})
		
		# 累加基础 value 与增强效果（红色蜡封除外，后续单独处理）
		pending_chips += card.get_value()
		var enhancement_bonus = _get_enhancement_bonus(card)
		pending_chips += enhancement_bonus["chips"]
		pending_mult += enhancement_bonus["mult"]
		
		# 处理蜡封
		match card.seal:
			"金色蜡封":
				MoneyManager.add_money(2)
			"红色蜡封":
				# 先统一 flush 已累加的筹码/倍率
				if pending_chips != 0:
					ScoreManager.add_chips(pending_chips)
					pending_chips = 0
				if pending_mult != 0:
					ScoreManager.add_mult(pending_mult)
					pending_mult = 0
				
				# 红色蜡封：该牌再次计分（动画 + 即时生效）
				var redo_tween = card.score_jump()
				if redo_tween:
					await redo_tween.finished
				ScoreManager.add_chips(card.get_value())
				_apply_enhancement_effect(card)
	
	# 循环结束后统一 flush 剩余累加值
	if pending_chips != 0:
		ScoreManager.add_chips(pending_chips)
	if pending_mult != 0:
		ScoreManager.add_mult(pending_mult)
	
	ScoreManager.recalculate()

	var chips = ScoreManager.base_chips + ScoreManager.current_chips
	var mult = ScoreManager.base_mult * ScoreManager.current_mult
	var score = ScoreManager.game_total_score
	print("牌型: ", hand_type, " | 计分牌数: ", scoring_cards.size(), " | 筹码: ", chips, " | 倍率: ", mult, " | 总分: ", score)
	hand_scored.emit(hand_type, chips, mult, score, to_play)
	
	# 第三步：统一销毁
	for card in to_play:
		var panel = card.get_parent() as Panel
		if panel:
			panel.queue_free()
		else:
			card.queue_free()
	hand_changed.emit()
	
	# 补牌
	await draw_cards_at_positions(to_play.size())
	
	# 出牌后重置临时筹码和回合分
	ScoreManager.reset_chips()
	
	plays_left -= 1
	plays_changed.emit(plays_left)
	
	if ScoreManager.game_total_score >= ScoreManager.target_score:
		ScoreManager.check_round_end()
	elif plays_left == 0:
		ScoreManager.check_round_end()
	
	return true

func _get_enhancement_bonus(card: PlayingCard) -> Dictionary:
	"""获取卡牌的增强效果加成（仅返回数值，不直接应用），返回 {chips, mult}"""
	var result = {"chips": 0, "mult": 0}
	match card.enhancement:
		"奖励牌":
			result.chips = 30
		"倍率牌":
			result.mult = 4
	return result

func _apply_enhancement_effect(card: PlayingCard) -> void:
	"""应用卡牌的增强效果（直接调用 ScoreManager)"""
	var bonus = _get_enhancement_bonus(card)
	if bonus.chips != 0:
		ScoreManager.add_chips(bonus.chips)
	if bonus.mult != 0:
		ScoreManager.add_mult(bonus.mult)

func _apply_seal_effect(card: PlayingCard) -> void:
	"""应用卡牌的蜡封效果"""
	match card.seal:
		"金色蜡封":
			MoneyManager.add_money(2)
		"红色蜡封":
			var redo_tween = card.score_jump()
			if redo_tween:
				await redo_tween.finished
			ScoreManager.add_chips(card.get_value())
			_apply_enhancement_effect(card)
	

func discard_selected_cards() -> bool:
	"""弃掉选中的卡牌"""
	if discards_left <= 0:
		print("本回合弃牌次数已用尽！")
		return false
	
	var to_discard = get_selected_cards()
	
	if to_discard.is_empty():
		print("没有选中的卡牌！")
		return false
	
	var card_names = to_discard.map(func(c): return c.get_card_name())
	print("弃掉卡牌: ", card_names)
	cards_discarded.emit(to_discard)
	
	# 标记并执行淡出动画
	for card in to_discard:
		card.mark_as_discarded()
	
	var discard_tween = create_tween()
	discard_tween.set_ease(Tween.EASE_IN)
	discard_tween.set_trans(Tween.TRANS_QUAD)
	for card in to_discard:
		discard_tween.parallel()
		discard_tween.parallel().tween_property(card, "global_position", card.global_position + Vector2(0, 120), 0.3)
		discard_tween.parallel().tween_property(card, "modulate", Color(1, 1, 1, 0), 0.3)
	
	await discard_tween.finished
	
	# 触发弃牌时小丑牌（ON_DISCARD）
	JokerManager.trigger_all(JokerCard.TriggerType.ON_DISCARD, {
		"discarded_cards": to_discard
	})
	
	for card in to_discard:
		var panel = card.get_parent() as Panel
		if panel:
			panel.queue_free()
		else:
			card.queue_free()
	
	ScoreManager.record_cards_discarded(to_discard.size())
	hand_changed.emit()
	await draw_cards_at_positions(to_discard.size())
	
	discards_left -= 1
	discards_changed.emit(discards_left)
	
	return true

func _get_active_cards() -> Array[PlayingCard]:
	"""获取当前所有活跃卡牌"""
	var cards: Array[PlayingCard] = []
	if desk == null:
		return cards
	for panel in desk.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is PlayingCard and child.state != PlayingCard.CardState.PLAYED and child.state != PlayingCard.CardState.DISCARDED:
					cards.append(child)
					break
	return cards

func _on_play_value_revealed(value: int):
	"""接收每张打出的卡牌传递的 value""" 
	print("卡牌贡献 value: ", value)

func draw_cards_at_positions(count: int):
	"""补指定数量的卡牌"""
	if desk == null:
		push_error("HandManager.desk 未设置，无法补牌")
		return
	
	for i in count:
		var data = DeckManager.draw_card()
		if data.is_empty():
			print("牌堆已空，无法补牌")
			break
		
		var card = CARD_SCENE.instantiate()
		card.suit = data.suit
		card.rank = data.rank
		card.seal = data.get("seal", "None")
		card.enhancement = data.get("enhancement", "None")
		
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(71.0, 95.0)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.self_modulate.a = 0
		desk.add_child(panel)
		card.position = Vector2.ZERO
		panel.add_child(card)
		
		register_card(card)
		arrange_hand()
		await get_tree().create_timer(0.15).timeout

func _update_ordered_hand_cards():
	"""按 desk 中 Panel 的顺序更新手牌顺序"""
	ordered_hand_cards.clear()
	if desk == null:
		return
	for panel in desk.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is PlayingCard and child.state != PlayingCard.CardState.PLAYED and child.state != PlayingCard.CardState.DISCARDED:
					ordered_hand_cards.append(child)
					break

func try_drop_card(card: PlayingCard) -> bool:
	"""尝试将拖拽的卡牌插入到鼠标位置对应的 slot，成功返回 true"""
	if desk == null:
		return false
	
	var mouse_pos = card.get_global_mouse_position()
	var target_slot = _get_slot_at_position(mouse_pos)
	
	# 如果鼠标不在任何 Panel 内，找 x 距离最近的 Panel
	if target_slot == null:
		target_slot = _get_nearest_slot(mouse_pos)
	
	var source_slot = card.get_parent() as Panel
	if target_slot == null or target_slot == source_slot:
		return false
	
	_insert_card_to_slot(card, source_slot, target_slot)
	return true

func _get_slot_at_position(global_pos: Vector2) -> Panel:
	"""获取鼠标位置下的 Panel slot"""
	if desk == null:
		return null
	for child in desk.get_children():
		if child is Panel:
			var rect = child.get_global_rect()
			if rect.has_point(global_pos):
				return child
	return null

func _get_nearest_slot(global_pos: Vector2) -> Panel:
	"""获取 x 轴距离最近的 Panel slot"""
	if desk == null:
		return null
	var nearest: Panel = null
	var min_dist = INF
	for child in desk.get_children():
		if child is Panel:
			var center_x = child.get_global_rect().get_center().x
			var dist = abs(global_pos.x - center_x)
			if dist < min_dist:
				min_dist = dist
				nearest = child
	return nearest

func _insert_card_to_slot(card_a: PlayingCard, source_slot: Panel, target_slot: Panel):
	"""插入式移动：将 source_slot 移动到 target_slot 的位置，中间所有卡牌自动移位"""
	var source_idx = source_slot.get_index()
	var target_idx = target_slot.get_index()
	if source_idx == target_idx:
		return
	
	# 收集所有活跃卡牌，记录它们当前的全局位置（用于动画）
	var affected_cards: Array[PlayingCard] = []
	var old_global_positions: Dictionary = {}
	for panel in desk.get_children():
		if panel is Panel:
			for child in panel.get_children():
				if child is PlayingCard and child.state != PlayingCard.CardState.PLAYED and child.state != PlayingCard.CardState.DISCARDED:
					affected_cards.append(child)
					old_global_positions[child] = child.global_position
					break
	
	# 移动 Panel 顺序（HBoxContainer 会自动重新排列其余 Panel）
	desk.move_child(source_slot, target_idx)
	
	# 恢复所有卡牌的全局位置，避免 HBoxContainer 重排导致的跳变
	for c in affected_cards:
		c.global_position = old_global_positions[c]
	
	# 动画：所有卡牌平滑滑入各自新 Panel 的中心
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	for c in affected_cards:
		tween.parallel()
		tween.tween_property(c, "position", Vector2.ZERO, 0.2)
	
	# 更新状态
	_finish_drag_state(card_a)
	_update_ordered_hand_cards()
	hand_changed.emit()

func _finish_drag_state(card: PlayingCard):
	"""结束拖拽状态，恢复正常"""
	card.state = PlayingCard.CardState.NORMAL
	card.z_index = card.original_z_index
	card._scale_card(1.0)
	card.state_changed.emit(PlayingCard.CardState.NORMAL, card)
