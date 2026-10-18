#version 450
layout(set = 2, binding = 0) uniform MaterialUniforms {
    float _Phase; // @default = 0.0
    float _Radius; // @default = 15.0
} uMaterial;
layout(location = 0) in vec2 fieldUV;
layout(location = 0) out vec4 outColor;

// Same axial hex grid and radial crest as WarpConsoleHoneycombFlow.
vec2 HexGrid(vec2 p, out vec2 local)
{
    vec2 axial = vec2(p.x / 1.7320508 - p.y / 3.0, p.y * (2.0 / 3.0));
    vec3 cube = vec3(axial, -axial.x - axial.y);
    vec3 rounded = round(cube);
    vec3 delta = abs(rounded - cube);
    if (delta.x > delta.y && delta.x > delta.z) rounded.x = -rounded.y - rounded.z;
    else if (delta.y > delta.z) rounded.y = -rounded.x - rounded.z;
    vec2 center = vec2(1.7320508 * (rounded.x + 0.5 * rounded.y), 1.5 * rounded.y);
    local = p - center;
    return center;
}

void main()
{
    vec2 p = (fieldUV - 0.5) * (2.0 * uMaterial._Radius);
    float radial = length(p);
    if (radial > uMaterial._Radius) discard;
    vec2 local;
    vec2 center = HexGrid(p, local);
    float edge = 0.8660254 - max(abs(local.x), max(abs(0.5 * local.x + 0.8660254 * local.y), abs(0.5 * local.x - 0.8660254 * local.y)));
    float aa = max(fwidth(edge), 0.008);
    // Both the base honeycomb and its pulse highlight use this three-times-thicker line mask.
    float line = 1.0 - smoothstep(0.075 - aa, 0.075 + aa, edge);
    float phase = length(center) / (2.0 * uMaterial._Radius) * 2.8 * 6.2831853 - uMaterial._Phase * 0.55 * 6.2831853;
    float crest = smoothstep(0.82, 1.0, cos(phase) * 0.5 + 0.5);
    float radialAA = max(fwidth(radial), 0.01);
    float rim = 1.0 - smoothstep(0.24, 0.24 + radialAA, uMaterial._Radius - radial);
    float alpha = max(line * (0.20 + 0.48 * crest), rim * 0.82);
    alpha *= smoothstep(0.0, radialAA, uMaterial._Radius - radial);
    vec3 color = mix(vec3(0.02, 0.60, 0.82), vec3(0.25, 0.96, 1.0), max(crest, rim));
    outColor = vec4(color, alpha);
}
