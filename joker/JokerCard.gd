class_name JokerCard extends Control

"""小丑牌基类
所有小丑牌效果统一在此类中根据 joker_id 判断，无需外部子类。
纹理行列由 _setup_by_id 手动配置，不再由 id 自动计算。
"""

# 触发时机枚举
enum TriggerType {
	INDEPENDENT,       # 持续生效
	ON_HAND_PLAYED,    # 出牌时（牌型判定后）
	ON_CARD_SCORED,    # 每张计分牌计分时
	ON_DISCARD,        # 弃牌时
	ON_ROUND_END,      # 回合结束时
	ON_BLIND_SELECTED, # 选择盲注时
}

# 小丑牌属性
@export var joker_id: int = 0
@export var joker_name: String = ""
@export var description: String = ""
@export var trigger_types: Array = []
@export var rarity: String = "普通"

# 纹理在精灵表中的手动配置行列
@export var atlas_row: int = 0
@export var atlas_col: int = 0

# 纹理配置
const JOKER_TEXTURE_PATH = "res://resources/textures/2x/Jokers.png"
const CARD_WIDTH = 142
const CARD_HEIGHT = 190

@onready var texture_rect: TextureRect = $TextureRect
@onready var button: Button = $Button

# 原始层级（悬停放大用）
var original_z_index: int = 0

# 悬浮提示
var tooltip_panel: Panel = null
var tooltip_name_label: Label = null
var tooltip_desc_label: Label = null
var tooltip_tween: Tween = null

# 拖拽相关
var is_held: bool = false
var has_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD = 5.0

func _ready():
	original_z_index = z_index
	if button:
		button.button_down.connect(_on_button_down)
		button.button_up.connect(_on_button_up)
		button.mouse_entered.connect(_on_mouse_entered)
		button.mouse_exited.connect(_on_mouse_exited)
	_update_texture()
	_create_tooltip()

# ============================================================
# 初始化方法
# ============================================================

func init_by_id(new_id: int) -> void:
	"""根据 id 初始化小丑牌（设置纹理、中文名称、效果配置）"""
	joker_id = new_id
	_setup_by_id(new_id)
	_update_texture()

func _setup_by_id(id: int) -> void:
	"""根据 id 手动配置小丑牌的中文名称、描述、触发时机和纹理行列。
	新增小丑牌时在此方法中添加对应 case 即可。
	"""
	match id:
		0:
			joker_name = "小丑"
			description = "倍率+4"
			trigger_types = [TriggerType.INDEPENDENT]
			atlas_row = 0
			atlas_col = 0
		1:
			joker_name = "贪婪小丑"
			description = "打出的方片牌在得分时使倍率+3"
			trigger_types = [TriggerType.ON_CARD_SCORED]
			atlas_row = 1
			atlas_col = 6
		2:
			joker_name = "色欲小丑"
			description = "打出的红桃牌在得分时使倍率+3"
			trigger_types = [TriggerType.ON_CARD_SCORED]
			atlas_row = 1
			atlas_col = 7
		3:
			joker_name = "愤怒小丑"
			description = "打出的黑桃牌在得分时使倍率+3"
			trigger_types = [TriggerType.ON_CARD_SCORED]
			atlas_row = 1
			atlas_col = 8
		4:
			joker_name = "暴食小丑"
			description = "打出的梅花牌在得分时使倍率+3"
			trigger_types = [TriggerType.ON_CARD_SCORED]
			atlas_row = 1
			atlas_col = 9
		5:
			joker_name = "开心小丑"
			description = "打出的牌含有对子时使倍率+8"
			trigger_types = [TriggerType.ON_HAND_PLAYED]
			atlas_row = 0
			atlas_col = 2
		6:
			joker_name = "古怪小丑"
			description = "打出的牌含有三条时使倍率+12"
			trigger_types = [TriggerType.ON_HAND_PLAYED]
			atlas_row = 0
			atlas_col = 3
		7:
			joker_name = "疯狂小丑"
			description = "打出的牌含有两对时使倍率+10"
			trigger_types = [TriggerType.ON_HAND_PLAYED]
			atlas_row = 0
			atlas_col = 4
		8:
			joker_name = "狂野小丑"
			description = "打出的牌含有顺子时使倍率+12"
			trigger_types = [TriggerType.ON_HAND_PLAYED]
			atlas_row = 0
			atlas_col = 5
		9:
			joker_name = "滑稽小丑"
			description = "打出的牌含有同花时使倍率+10"
			trigger_types = [TriggerType.ON_HAND_PLAYED]
			atlas_row = 0
			atlas_col = 6
		_:
			joker_name = "未知小丑"
			description = "无效果"
			trigger_types = []
			atlas_row = 0
			atlas_col = 0

# ============================================================
# 工具提示
# ============================================================

func _create_tooltip() -> void:
	"""创建悬浮提示面板（初始隐藏）"""
	tooltip_panel = Panel.new()
	tooltip_panel.visible = false
	tooltip_panel.z_index = 200
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.05, 0.94)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.75, 0.3, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	tooltip_panel.add_child(vbox)

	tooltip_name_label = Label.new()
	tooltip_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_name_label.add_theme_font_size_override("font_size", 15)
	tooltip_name_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	vbox.add_child(tooltip_name_label)

	tooltip_desc_label = Label.new()
	tooltip_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_desc_label.add_theme_font_size_override("font_size", 13)
	tooltip_desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(tooltip_desc_label)

	add_child(tooltip_panel)

func _update_tooltip_text() -> void:
	"""更新工具提示文本并调整面板大小"""
	if tooltip_name_label == null or tooltip_desc_label == null:
		return
	tooltip_name_label.text = joker_name
	tooltip_desc_label.text = " " + description

	# 根据文本内容计算面板所需尺寸
	var name_min = tooltip_name_label.get_minimum_size()
	var desc_min = tooltip_desc_label.get_minimum_size()
	var max_w = max(name_min.x, desc_min.x)
	var total_h = name_min.y + desc_min.y + 2  # +2 separation
	if max_w > 0 and total_h > 0:
		tooltip_panel.custom_minimum_size = Vector2(max_w + 20, total_h + 12)

func _show_tooltip() -> void:
	"""显示工具提示（带淡入动画）"""
	if tooltip_panel == null:
		return
	_update_tooltip_text()

	# 计算位置：面板底部，水平居中于卡牌
	var card_height = size.y if size.y > 0 else 95.0
	var card_width = size.x if size.x > 0 else 71.0
	var panel_w = tooltip_panel.custom_minimum_size.x
	if panel_w <= 0:
		panel_w = 100
	var center_x = (card_width - panel_w) / 2.0
	tooltip_panel.position = Vector2(center_x, card_height + 4)

	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0
	if tooltip_tween and tooltip_tween.is_valid():
		tooltip_tween.kill()
	tooltip_tween = create_tween()
	tooltip_tween.set_ease(Tween.EASE_OUT)
	tooltip_tween.set_trans(Tween.TRANS_QUAD)
	tooltip_tween.tween_property(tooltip_panel, "modulate", Color(1, 1, 1, 1), 0.15)

func _hide_tooltip() -> void:
	"""隐藏工具提示"""
	if tooltip_panel == null:
		return
	if tooltip_tween and tooltip_tween.is_valid():
		tooltip_tween.kill()
	tooltip_tween = create_tween()
	tooltip_tween.set_ease(Tween.EASE_IN)
	tooltip_tween.set_trans(Tween.TRANS_QUAD)
	tooltip_tween.tween_property(tooltip_panel, "modulate", Color(1, 1, 1, 0), 0.1)
	tooltip_tween.finished.connect(func(): tooltip_panel.visible = false)

# ============================================================
# 纹理更新
# ============================================================

func _update_texture() -> void:
	if texture_rect == null:
		return
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = load(JOKER_TEXTURE_PATH)
	atlas_texture.region = _get_joker_region()
	texture_rect.texture = atlas_texture

func _get_joker_region() -> Rect2:
	"""根据手动配置的行列计算在精灵表中的裁剪区域"""
	return Rect2(atlas_col * CARD_WIDTH, atlas_row * CARD_HEIGHT, CARD_WIDTH, CARD_HEIGHT)

# ============================================================
# 触发接口
# ============================================================

func can_trigger(trigger_type: TriggerType, context: Dictionary = {}) -> bool:
	"""判断当前小丑牌是否对给定时机有反应。"""
	if trigger_type == TriggerType.INDEPENDENT:
		return trigger_types.has(TriggerType.INDEPENDENT)
	return trigger_types.has(trigger_type)

func on_trigger(trigger_type: TriggerType, context: Dictionary = {}) -> Dictionary:
	"""根据 joker_id 执行对应小丑牌效果。
	返回 Dictionary: {chips: int, mult: float, money: int}
	"""
	match joker_id:
		0:  # 小丑 — 持续 +4 倍率
			if trigger_type == TriggerType.INDEPENDENT:
				return {"chips": 0, "mult": 4.0, "money": 0}

		1:  # 贪婪小丑 — 方片牌得分时 +3 倍率
			if trigger_type == TriggerType.ON_CARD_SCORED:
				var scoring_card = context.get("scoring_card", null)
				if scoring_card and scoring_card.get_suit() == "Diamond":
					return {"chips": 0, "mult": 3.0, "money": 0}

		2:  # 色欲小丑 — 红桃牌得分时 +3 倍率
			if trigger_type == TriggerType.ON_CARD_SCORED:
				var scoring_card = context.get("scoring_card", null)
				if scoring_card and scoring_card.get_suit() == "Heart":
					return {"chips": 0, "mult": 3.0, "money": 0}

		3:  # 愤怒小丑 — 黑桃牌得分时 +3 倍率
			if trigger_type == TriggerType.ON_CARD_SCORED:
				var scoring_card = context.get("scoring_card", null)
				if scoring_card and scoring_card.get_suit() == "Spade":
					return {"chips": 0, "mult": 3.0, "money": 0}

		4:  # 暴食小丑 — 梅花牌得分时 +3 倍率
			if trigger_type == TriggerType.ON_CARD_SCORED:
				var scoring_card = context.get("scoring_card", null)
				if scoring_card and scoring_card.get_suit() == "Club":
					return {"chips": 0, "mult": 3.0, "money": 0}

		5:  # 开心小丑 — 对子时 +8 倍率
			if trigger_type == TriggerType.ON_HAND_PLAYED:
				var hand_type = context.get("hand_type", "")
				if hand_type == "Pair":
					return {"chips": 0, "mult": 8.0, "money": 0}

		6:  # 古怪小丑 — 三条时 +12 倍率
			if trigger_type == TriggerType.ON_HAND_PLAYED:
				var hand_type = context.get("hand_type", "")
				if hand_type == "Three of a Kind":
					return {"chips": 0, "mult": 12.0, "money": 0}

		7:  # 疯狂小丑 — 两对时 +10 倍率
			if trigger_type == TriggerType.ON_HAND_PLAYED:
				var hand_type = context.get("hand_type", "")
				if hand_type == "Two Pair":
					return {"chips": 0, "mult": 10.0, "money": 0}

		8:  # 狂野小丑 — 顺子时 +12 倍率
			if trigger_type == TriggerType.ON_HAND_PLAYED:
				var hand_type = context.get("hand_type", "")
				if hand_type == "Straight" or hand_type == "Straight Flush":
					return {"chips": 0, "mult": 12.0, "money": 0}

		9:  # 滑稽小丑 — 同花时 +10 倍率
			if trigger_type == TriggerType.ON_HAND_PLAYED:
				var hand_type = context.get("hand_type", "")
				if hand_type == "Flush" or hand_type == "Straight Flush" or hand_type == "Flush House" or hand_type == "Flush Five":
					return {"chips": 0, "mult": 10.0, "money": 0}

	return {"chips": 0, "mult": 0.0, "money": 0}

# ============================================================
# 拖拽逻辑
# ============================================================

func _process(_delta):
	if is_held and not has_dragged:
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.distance_to(drag_start_mouse_pos) > DRAG_THRESHOLD:
			has_dragged = true
			z_index = 100
			var parent = get_parent()
			if parent:
				drag_offset = (mouse_pos - parent.global_position) - position

	if has_dragged:
		var parent = get_parent()
		if parent:
			position = (get_global_mouse_position() - parent.global_position) - drag_offset

func _on_button_down():
	is_held = true
	has_dragged = false
	drag_start_mouse_pos = get_global_mouse_position()

func _on_button_up():
	is_held = false
	if has_dragged:
		var dropped = JokerManager.try_drop_joker(self)
		if not dropped:
			return_to_slot()
		has_dragged = false

func return_to_slot():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", Vector2.ZERO, 0.3)
	z_index = original_z_index
	_scale_card(1.0)

# ============================================================
# 视觉效果
# ============================================================

func _on_mouse_entered() -> void:
	z_index = 100
	_scale_card(1.08)
	_show_tooltip()

func _on_mouse_exited() -> void:
	z_index = original_z_index
	_scale_card(1.0)
	_hide_tooltip()

func _scale_card(scale_factor: float) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.15)
