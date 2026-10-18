#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _HexDarkColor; // @color @default = vec4(0.012000000104308128, 0.01600000075995922, 0.02199999988079071, 1.0)
    vec4 _HexGlowColor; // @color @default = vec4(1.0, 0.6399999856948853, 0.05999999865889549, 1.0)
    vec4 _IconTint; // @color @default = vec4(1.0, 1.0, 1.0, 1.0)
    vec4 _TextColor; // @color @default = vec4(1.0, 0.8299999833106995, 0.3199999928474426, 1.0)
    vec4 _Time;
    float _CornerCut; // @default = 0.04899999871850014
    float _DisplayAspect; // @default = 1.0
    float _GlyphCount; // @default = 0.0
    float _HasItem; // @default = 0.0
    float _HasText; // @default = 0.0
    float _HexScale; // @default = 13.0
    float _ItemAspect; // @default = 1.0
    float _PowerLevel; // @default = 1.0
    float _PulseSpeed; // @default = 0.75
    float _TimeOffset; // @default = 0.0
} uMaterial;
layout(set = 2, binding = 1) uniform sampler2D _ItemTex;
layout(set = 2, binding = 2) uniform sampler2D _FontAtlas;
layout(std430, set = 2, binding = 3) readonly buffer _GlyphRects { vec4 values[]; } pm_GlyphRects;
layout(std430, set = 2, binding = 4) readonly buffer _GlyphUvBottomLeft { vec4 values[]; } pm_GlyphUvBottomLeft;
layout(std430, set = 2, binding = 5) readonly buffer _GlyphUvBottomRight { vec4 values[]; } pm_GlyphUvBottomRight;
layout(std430, set = 2, binding = 6) readonly buffer _GlyphUvTopLeft { vec4 values[]; } pm_GlyphUvTopLeft;
layout(std430, set = 2, binding = 7) readonly buffer _GlyphUvTopRight { vec4 values[]; } pm_GlyphUvTopRight;

#define UNITY_PI 3.14159265358979323846
#define UNITY_TWO_PI 6.28318530717958647692
#define saturate(x) clamp(x, 0.0, 1.0)
#define rsqrt(x) inversesqrt(x)
#define fmod(x,y) ((x) - (y) * trunc((x)/(y)))
#define TRANSFORM_TEX(uv,tex) ((uv).xy * tex##_ST.zw + tex##_ST.xy)
#define mul(a,b) ((a)*(b))
#define unity_ObjectToWorld push.modelMatrix
vec4 UnityObjectToClipPos(vec4 p) { return uVertex.ViewProj * push.modelMatrix * p; }
vec4 UnityObjectToClipPos(vec3 p) { return UnityObjectToClipPos(vec4(p,1.0)); }
vec4 ComputeGrabScreenPos(vec4 p) { return vec4(p.xy * .5 + p.ww * .5, p.zw); }
vec4 PMTexture(sampler2D image, vec2 uv) { return texture(image,vec2(uv.x,1.0-uv.y)); }
void PMSincos(float a, out float s, out float c) {s=sin(a);c=cos(a);}
float distance(vec2 p, float q) {return length(p-vec2(q));}
#ifdef PM_VERTEX
#define fwidth(x) ((x)*0.0)
#define dFdx(x) ((x)*0.0)
#define dFdy(x) ((x)*0.0)
void clip(float v) {}
#else
// Unity's Vulkan binaries use coarse derivatives for HLSL fwidth/ddx/ddy.
// Native GLSL's unspecified derivative choice can change fine line coverage.
#define fwidth(x) (abs(dFdxCoarse(x)) + abs(dFdyCoarse(x)))
#define dFdx(x) dFdxCoarse(x)
#define dFdy(x) dFdyCoarse(x)
void clip(float v) {if(v<0.0)discard;}
#endif



            #define PM_MAX_GLYPHS 19

            struct appdata
            {
                vec4 vertex ;
                vec2 uv ;
            };

            struct v2f
            {
                vec4 vertex ;
                vec2 uv ;
            };

            v2f vert(appdata vertexInput)
            {
                v2f vertexOutput;
                vertexOutput.vertex = UnityObjectToClipPos(vertexInput.vertex);
                vertexOutput.uv = vertexInput.uv;
                return vertexOutput;
            }

            float Hash21(vec2 value)
            {
                value = fract(value * vec2(123.34, 456.21));
                value += dot(value, value + 45.32);
                return fract(value.x * value.y);
            }

            float HexDistance(vec2 p)
            {
                p = abs(p);
                return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
            }

            vec2 HexCell(vec2 p, out vec2 cellId)
            {
                const vec2 grid = vec2(1.0, 1.7320508);
                const vec2 halfGrid = vec2(0.5, 0.8660254);

                vec2 candidateA = fract(p / grid) * grid - halfGrid;
                vec2 candidateB = fract((p - halfGrid) / grid) * grid - halfGrid;
                float useA = step(dot(candidateA, candidateA), dot(candidateB, candidateB));
                vec2 local = mix(candidateB, candidateA, useA);
                cellId = p - local;
                return local;
            }

            float ScreenMask(vec2 uv)
            {
                vec2 edgeDistance = 0.5 - abs(uv - 0.5);
                float sideMask = min(edgeDistance.x, edgeDistance.y);
                float chamferMask = edgeDistance.x + edgeDistance.y - uMaterial._CornerCut;
                return min(sideMask, chamferMask);
            }

            vec4 Honeycomb(vec2 uv)
            {
                float safeAspect = max(uMaterial._DisplayAspect, 0.001);
                vec2 honeyUv = uv - 0.5;
                honeyUv.x *= safeAspect;
                honeyUv *= max(uMaterial._HexScale, 0.001);

                vec2 cellId;
                vec2 local = HexCell(honeyUv, cellId);
                float hexDistance = HexDistance(local);
                float antialias = max(fwidth(hexDistance) * 1.25, 0.001);
                float border = smoothstep(0.405 - antialias, 0.475 + antialias, hexDistance);

                float randomPhase = Hash21(cellId) * 6.2831853;
                float time = uMaterial._Time.y * uMaterial._PulseSpeed + uMaterial._TimeOffset;
                float wave = 0.5 + 0.5 * sin(
                    time * 2.1
                    - cellId.y * 0.62
                    + cellId.x * 0.28
                    + randomPhase * 0.22);
                wave *= wave;

                float slowBreath = 0.72 + 0.28 * sin(time * 0.73 + uv.y * 3.1);
                float cellVariation = 0.78 + Hash21(cellId + 19.7) * 0.22;
                vec3 dark = uMaterial._HexDarkColor.rgb * cellVariation;
                float glowStrength = border * (0.13 + wave * 0.72) * slowBreath * uMaterial._PowerLevel;
                vec3 color = dark + uMaterial._HexGlowColor.rgb * glowStrength;

                float sweep = pow(saturate(
                    1.0 - abs(fract(uv.y - time * 0.035) - 0.5) * 8.0), 3.0);
                color += uMaterial._HexGlowColor.rgb * sweep * 0.035 * uMaterial._PowerLevel;

                float vignette = saturate(1.12 - dot(uv - 0.5, uv - 0.5) * 1.15);
                color *= vignette;
                return vec4(color, uMaterial._HexDarkColor.a);
            }

            vec4 DrawItem(vec2 uv, vec4 underColor)
            {
                if (uMaterial._HasItem < 0.5)
                    return underColor;

                float safeDisplayAspect = max(uMaterial._DisplayAspect, 0.001);
                float uvAspect = max(uMaterial._ItemAspect, 0.001) / safeDisplayAspect;
                vec2 maxSize = uMaterial._HasText > 0.5
                    ? vec2(0.72, 0.57)
                    : vec2(0.78, 0.76);
                vec2 iconSize;
                if (maxSize.y * uvAspect <= maxSize.x)
                    iconSize = vec2(maxSize.y * uvAspect, maxSize.y);
                else
                    iconSize = vec2(maxSize.x, maxSize.x / uvAspect);

                vec2 center = uMaterial._HasText > 0.5
                    ? vec2(0.5, 0.625)
                    : vec2(0.5, 0.5);
                vec2 localUv = (uv - center) / max(iconSize, 0.001) + 0.5;
                float inside = step(0.0, localUv.x)
                    * step(localUv.x, 1.0)
                    * step(0.0, localUv.y)
                    * step(localUv.y, 1.0);

                vec4 icon = PMTexture(_ItemTex, saturate(localUv)) * uMaterial._IconTint;
                float iconAlpha = icon.a * inside;

                float halo = iconAlpha * (1.0 - iconAlpha) * 0.35;
                underColor.rgb += uMaterial._HexGlowColor.rgb * halo * uMaterial._PowerLevel;
                underColor.rgb = mix(underColor.rgb, icon.rgb, iconAlpha);
                return underColor;
            }

            vec4 DrawGlyphs(vec2 uv, vec4 underColor)
            {
                if (uMaterial._HasText < 0.5 || uMaterial._GlyphCount < 0.5)
                    return underColor;

                float coverage = 0.0;

                for (int glyphIndex = 0; glyphIndex < PM_MAX_GLYPHS; glyphIndex++)
                {
                    float isActive = step(glyphIndex + 0.5, uMaterial._GlyphCount);
                    vec4 rect = pm_GlyphRects.values[glyphIndex];
                    vec2 safeSize = max(rect.zw, 0.00001);
                    vec2 glyphUv = (uv - rect.xy) / safeSize;
                    float inside = step(0.0, glyphUv.x)
                        * step(glyphUv.x, 1.0)
                        * step(0.0, glyphUv.y)
                        * step(glyphUv.y, 1.0);

                    vec2 bottomUv = mix(
                        pm_GlyphUvBottomLeft.values[glyphIndex].xy,
                        pm_GlyphUvBottomRight.values[glyphIndex].xy,
                        saturate(glyphUv.x));
                    vec2 topUv = mix(
                        pm_GlyphUvTopLeft.values[glyphIndex].xy,
                        pm_GlyphUvTopRight.values[glyphIndex].xy,
                        saturate(glyphUv.x));
                    vec2 atlasUv = mix(bottomUv, topUv, saturate(glyphUv.y));
                    float alpha = PMTexture(_FontAtlas, atlasUv).a * inside * isActive;
                    coverage = max(coverage, alpha);
                }

                underColor.rgb = mix(
                    underColor.rgb,
                    uMaterial._TextColor.rgb,
                    coverage * uMaterial._TextColor.a);
                return underColor;
            }

            vec4 frag(v2f vertexInput) 
            {
                clip(ScreenMask(vertexInput.uv));

                vec4 color = Honeycomb(vertexInput.uv);
                color = DrawItem(vertexInput.uv, color);
                color = DrawGlyphs(vertexInput.uv, color);
                color.a = 1.0;
                return color;
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 0) out vec2 pmVuv;
void main() {
appdata pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.uv = pmInuv;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.vertex;
pmVuv = pmOutput.uv;
}
