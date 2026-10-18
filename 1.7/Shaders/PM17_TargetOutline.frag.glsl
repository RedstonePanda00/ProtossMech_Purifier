#version 450
layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 2, binding = 0) uniform MaterialUniforms
{
    vec4 _Color; // @color @default = vec4(1.0, 0.0, 0.0, 1.0)
    vec4 _MainTex_TexelSize; // @default = vec4(0.001953125, 0.001953125, 512.0, 512.0)
    float _PaddingPixels; // @default = 2.5
} uMaterial;
layout(set = 2, binding = 1) uniform sampler2D _MainTex;
float alphaAt(vec2 uv)
{
    float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
    // Match the texture orientation used by the target capture and legacy sampler.
    return smoothstep(0.08, 0.35, texture(_MainTex, vec2(uv.x, 1.0 - uv.y)).a) * inside;
}
void main()
{
    float center = alphaAt(vUv);
    vec2 radius = max(fwidth(vUv), abs(uMaterial._MainTex_TexelSize.xy)) * uMaterial._PaddingPixels;
    float expanded = center;
    for (int i = 0; i < 16; ++i)
    {
        float angle = float(i) * (6.28318530718 / 16.0);
        vec2 direction = vec2(cos(angle), sin(angle));
        expanded = max(expanded, alphaAt(vUv + direction * radius));
        expanded = max(expanded, alphaAt(vUv + direction * radius * 0.5));
    }
    outColor = vec4(uMaterial._Color.rgb, clamp(expanded - center, 0.0, 1.0) * uMaterial._Color.a);
}
