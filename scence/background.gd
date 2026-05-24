extends ColorRect

var elapsed: float = 0.0

func _process(delta):
    elapsed += delta  # delta 是上一帧到这一帧的间隔（秒）
    material.set_shader_parameter("time", elapsed)
    material.set_shader_parameter("spin_time", elapsed * 0.5)