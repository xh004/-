# money_manager.gd（AutoLoad）
extends Node

signal money_increased(amount: int, current: int)
signal money_decreased(amount: int, current: int)
signal money_changed(current: int)

var current_money: int = 0

func _ready():
	reset_money()

func reset_money():
	"""重置金钱为0"""
	current_money = 0
	money_changed.emit(current_money)

func add_money(amount: int):
	"""增加金钱"""
	if amount <= 0:
		return
	current_money += amount
	money_increased.emit(amount, current_money)
	money_changed.emit(current_money)

func spend_money(amount: int) -> bool:
	"""消耗金钱，余额不足返回 false"""
	if amount <= 0:
		return true
	if current_money < amount:
		print("金钱不足！需要 ", amount, "，当前 ", current_money)
		return false
	current_money -= amount
	money_decreased.emit(amount, current_money)
	money_changed.emit(current_money)
	return true

func can_afford(amount: int) -> bool:
	"""检查是否买得起"""
	return current_money >= amount

func get_money() -> int:
	"""获取当前金钱"""
	return current_money
