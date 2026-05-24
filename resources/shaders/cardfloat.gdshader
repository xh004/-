shader_type canvas_item;

// 晃动参数
uniform float wobble_speed : hint_range(0.0, 10.0) = 2.0;      // 晃动速度
uniform float wobble_amount : hint_range(0.0, 0.5) = 0.05;     // 晃动幅度（弧度）
uniform float breathe_scale : hint_range(0.0, 0.1) = 0.02;     // 呼吸缩放幅度

// 可选：选中状态增强
uniform bool is_selected = false;
uniform float selected_intensity : hint_range(0.0, 2.0) = 1.5;

void vertex() {
    // 时间因子
    float time = TIME * wobble_speed;
    
    // 选中时增强效果
    float intensity = is_selected ? selected_intensity : 1.0;
    
    // 1. 轻微旋转晃动（绕Z轴）
    float angle = sin(time) * wobble_amount * intensity;
    
    // 2. 轻微位移（上下浮动）
    vec2 offset = vec2(
        cos(time * 0.7) * wobble_amount * 10.0,  // X轴轻微
        sin(time * 0.5) * wobble_amount * 20.0   // Y轴明显
    );  
    
    // 3. 呼吸缩放
    float scale = 1.0 + sin(time * 0.8) * breathe_scale * intensity;
    
    // 应用变换
    // 先缩放
    VERTEX *= scale;
    
    // 再旋转（2D旋转矩阵）
    mat2 rotation = mat2(
        vec2(cos(angle), -sin(angle)),
        vec2(sin(angle), cos(angle))
    );
    VERTEX = rotation * VERTEX;
    
    // 最后位移
    VERTEX += offset;
}