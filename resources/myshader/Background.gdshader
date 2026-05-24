shader_type canvas_item;

uniform float time : hint_range(0.0, 100.0);
uniform float spin_time : hint_range(0.0, 100.0);
uniform vec4 colour_1 : source_color = vec4(0.8, 0.2, 0.2, 1.0);   // 红
uniform vec4 colour_2 : source_color = vec4(0.2, 0.2, 0.8, 1.0);   // 蓝
uniform vec4 colour_3 : source_color = vec4(0.9, 0.9, 0.9, 1.0);   // 白
uniform float contrast : hint_range(0.0, 5.0) = 1.0;
uniform float spin_amount : hint_range(0.0, 2.0) = 0.5;

#define PIXEL_SIZE_FAC 700.0
#define SPIN_EASE 0.5

void fragment() {
    // 屏幕尺寸（Godot 用 FRAGCOORD 和 SCREEN_PIXEL_SIZE）
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    float pixel_size = length(screen_size) / PIXEL_SIZE_FAC;
    
    // UV 转换 + 像素化
    vec2 uv = (floor(FRAGCOORD.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screen_size) / length(screen_size) - vec2(0.12, 0.0);
    float uv_len = length(uv);
    
    // 中心漩涡
    float speed = (spin_time * SPIN_EASE * 0.2) + 302.2;
    float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE * 20.0 * (1.0 * spin_amount * uv_len + (1.0 - 1.0 * spin_amount));
    vec2 mid = (screen_size / length(screen_size)) / 2.0;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
    
    // 颜料效果
    uv *= 30.0;
    speed = time * 2.0;
    vec2 uv2 = vec2(uv.x + uv.y);
    
    for(int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
        uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
    }
    
    // 颜色混合
    float contrast_mod = (0.25 * contrast + 0.5 * spin_amount + 1.2);
    float paint_res = min(2.0, max(0.0, length(uv) * (0.035) * contrast_mod));
    float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
    float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
    float c3p = 1.0 - min(1.0, c1p + c2p);
    
    vec4 ret_col = (0.3 / contrast) * colour_1 + (1.0 - 0.3 / contrast) * (colour_1 * c1p + colour_2 * c2p + vec4(c3p * colour_3.rgb, c3p * colour_1.a));
    
    COLOR = ret_col;
}