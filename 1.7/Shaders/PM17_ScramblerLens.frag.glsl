#version 450
layout(location = 0) in vec2 vUv;
layout(location = 1) flat in vec2 vCenter;
layout(location = 0) out vec4 outColor;
layout(set = 2, binding = 0) uniform MaterialUniforms
{
    float _Phase; // @default = 0.0
    float _Bend; // @default = 0.26
    float _Visibility; // @default = 1.0
} uMaterial;
// SceneGrabPoint exposes its native texture as "_Grab" + sceneGrab.name.
layout(set = 2, binding = 1) uniform sampler2D _Grab_PMScramblerBackground;
void main()
{
    float r = length((vUv - 0.5) * 2.0);
    float progress = fract(uMaterial._Phase * 0.5);
    float radius = mix(0.08, 1.08, progress);
    float ring = 1.0 - smoothstep(0.035, 0.14, abs(r - radius));
    float fade = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.72, 1.0, progress));
    float mask = ring * fade * (1.0 - smoothstep(0.88, 1.0, r)) * uMaterial._Visibility;
    if (mask < 0.002) discard;
    vec2 size = vec2(textureSize(_Grab_PMScramblerBackground, 0));
    vec2 screen = gl_FragCoord.xy / size;
    vec2 sampleUv = screen - (screen - vCenter) * uMaterial._Bend * (1.0 - 0.4 * progress);
    vec2 safe = 1.5 / size;
    outColor = vec4(texture(_Grab_PMScramblerBackground, clamp(sampleUv, safe, 1.0 - safe)).rgb, mask);
}
