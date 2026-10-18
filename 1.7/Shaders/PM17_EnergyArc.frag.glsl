#version 450
layout(location = 0) in vec2 vUv;
layout(location = 0) out vec4 outColor;
layout(set = 2, binding = 0) uniform MaterialUniforms
{
    vec4 _Color; // @color @default = vec4(0.15, 0.65, 1.0, 1.0)
    vec4 _CoreColor; // @color @default = vec4(0.8, 0.95, 1.0, 1.0)
    float _ArcFrame; // @default = 0.0
    float _Seed; // @default = 0.0
    float _Pulse; // @default = 1.0
    float _Strands; // @default = 3.0
    float _Segments; // @default = 11.0
    float _MainAmplitude; // @default = 0.25
    float _BranchAmplitude; // @default = 0.35
    float _BranchIntensity; // @default = 0.4
    float _CoreWidth; // @default = 0.025
    float _GlowFalloff; // @default = 24.0
    float _GlowStrength; // @default = 0.65
    float _EndFade; // @default = 0.045
} uMaterial;
float hashNode(float node, float strand, float phase)
{
    vec3 p = fract(vec3(node + strand * 19.0, phase, uMaterial._Seed) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float jagged(float along, float strand)
{
    float p = along * max(1.0, uMaterial._Segments);
    float k = floor(p);
    float a = hashNode(k, strand, uMaterial._ArcFrame) * 2.0 - 1.0;
    float b = hashNode(k + 1.0, strand, uMaterial._ArcFrame) * 2.0 - 1.0;
    return mix(a, b, fract(p)) * sin(along * 3.14159265359);
}
void main()
{
    float t = clamp(vUv.y, 0.0, 1.0);
    float side = vUv.x - 0.5;
    float core = 0.0, glow = 0.0;
    for (int strand = 0; strand < 8; ++strand)
    {
        if (float(strand) >= uMaterial._Strands) continue;
        float path = jagged(t, float(strand)) * (strand == 0 ? uMaterial._MainAmplitude : uMaterial._BranchAmplitude);
        float d = abs(side - path);
        float aa = max(fwidth(d), 0.002);
        float weight = strand == 0 ? 1.0 : uMaterial._BranchIntensity;
        core += weight * (1.0 - smoothstep(uMaterial._CoreWidth - aa, uMaterial._CoreWidth + aa, d));
        glow += weight * exp(-d * max(0.01, uMaterial._GlowFalloff)) * uMaterial._GlowStrength;
    }
    float fade = max(0.0001, uMaterial._EndFade);
    float ends = smoothstep(0.0, fade, t) * smoothstep(0.0, fade, 1.0 - t);
    float intensity = clamp(core + glow, 0.0, 1.0) * ends * uMaterial._Pulse;
    outColor = vec4(mix(uMaterial._Color.rgb, uMaterial._CoreColor.rgb, clamp(core, 0.0, 1.0)), intensity * uMaterial._Color.a);
}
