shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    COLOR = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
    // Làm tối thêm một chút bằng cách nhân với màu đen trong suốt
    COLOR.rgb *= 0.7; 
}