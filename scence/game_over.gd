extends CanvasLayer

# 接收主场景传来的数据
var stats: Dictionary = {}

@onready var stats_grid : GridContainer = $MainPanel/VBoxContainer2/StateGrid

func _ready():
	# 填充统计数据
	update_stats() 
	# 入场动画
	animate_in()

func update_stats():
	# 清空现有
	for child in stats_grid.get_children():
		child.queue_free()
	
	# 动态添加统计行
	var data = {
		"最佳出牌": stats.get("最佳出牌", 0),
		"最常用牌型": stats.get("最常用牌型", "无"),
		"已使用卡牌": stats.get("已使用卡牌", 0),
		"已弃掉卡牌": stats.get("已弃掉卡牌", 0),
		"已购买卡牌": stats.get("已购买卡牌", 0),
		"种子": stats.get("种子", "------")
	}
	
	for key in data.keys():
		var label = Label.new()
		label.text = key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_grid.add_child(label)
		
		var value = Label.new()
		value.text = str(data[key])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		stats_grid.add_child(value)

func animate_in():
	$MainPanel.scale = Vector2.ZERO
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property($MainPanel, "scale", Vector2.ONE, 0.5)

func _on_restart():
	get_tree().reload_current_scene()

func _on_main_menu():
	# 取消暂停，返回主菜单
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scence/main_menu.tscn")
