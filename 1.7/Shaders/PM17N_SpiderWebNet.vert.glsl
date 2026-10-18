#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BaseColor; // @color @default = vec4(0.8799999952316284, 0.9300000071525574, 1.0, 1.0)
    vec4 _HighlightColor; // @color @default = vec4(1.0, 1.0, 1.0, 1.0)
    vec4 _LightDir; // @default = vec4(0.3499999940395355, 0.6499999761581421, 0.5, 0.0)
    vec4 _Time;
    float _Appear; // @default = 1.0
    float _BaseAlpha; // @default = 0.550000011920929
    float _BeadBrightness; // @default = 1.5
    float _BeadDensity; // @default = 22.0
    float _BeadOnRadial; // @default = 0.0
    float _BeadSize; // @default = 0.8500000238418579
    float _CatenaryAmt; // @default = 0.02500000037252903
    float _IridescenceOffset; // @default = 0.11999999731779099
    float _IridescenceStrength; // @default = 0.25
    float _MaxRadius; // @default = 0.9200000166893005
    float _MicroWaveAmp; // @default = 0.004000000189989805
    float _MicroWaveFreq; // @default = 17.0
    float _OriginFade; // @default = 0.04500000178813934
    float _RadialWidth; // @default = 0.002199999988079071
    float _RimStrength; // @default = 0.6000000238418579
    float _SpecWidth; // @default = 0.14000000059604645
    float _SpiralBreakLen; // @default = 0.04500000178813934
    float _SpiralBreakProb; // @default = 0.11999999731779099
    float _SpiralCount; // @default = 24.0
    float _SpiralIrregular; // @default = 0.017999999225139618
    float _SpiralSpacingVar; // @default = 0.30000001192092896
    float _SpiralWidth; // @default = 0.0017999999690800905
    float _SpokeBreakLen; // @default = 0.03500000014901161
    float _SpokeBreakProb; // @default = 0.07999999821186066
    float _SpokeCount; // @default = 28.0
    float _SpokeIrregular; // @default = 0.3400000035762787
    float _VibAmp; // @default = 0.006000000052154064
    float _VibFreq; // @default = 1.2000000476837158
    float _VibPropDelay; // @default = 1.0
    float _WidthVariation; // @default = 0.3799999952316284
} uMaterial;

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

float PMWebAngle(float y, float x) {
    float ratio = min(abs(x), abs(y)) * (1.0 / max(max(abs(x), abs(y)), 1e-20));
    float r2 = ratio * ratio;
    float p = r2 * 0.0208351 - 0.085133;
    p = r2 * p + 0.180141;
    p = r2 * p - 0.3302995;
    p = r2 * p + 0.999866;
    float a = ratio * p;
    a += abs(x) < abs(y) ? a * -2.0 + 1.5707963705062866 : 0.0;
    a += x < 0.0 ? -3.1415927410125732 : 0.0;
    return max(x,y) >= 0.0 && min(x,y) < 0.0 ? -a : a;
}


            #define TAU 6.28318530718

            struct appdata { vec4 vertex ; vec2 uv ; };
            struct v2f { vec4 pos ; vec2 uv ; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float hash11(float n) { return fract(sin(n) * 43758.5453123); }
            float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }

            float lineMask(float dist, float width)
            {
                float aa = max(fwidth(dist), 0.00075);
                return 1.0 - smoothstep(width, width + aa, dist);
            }

            float angleDistanceToSpoke(float a01, float r, out float nearestId)
            {
                float x = a01 * uMaterial._SpokeCount;
                float baseId = floor(x);
                float best = 10.0;
                nearestId = baseId;

                 for (int k = -1; k <= 1; k++)
                {
                    float id = baseId + k;
                    float jitter = (hash11(id + 17.3) - 0.5) * uMaterial._SpokeIrregular * 0.65;
                    float spoke = (id + jitter) / uMaterial._SpokeCount;
                    float d = abs(fract(a01 - spoke + 0.5) - 0.5) * TAU * r;
                    if (d < best) { best = d; nearestId = id; }
                }
                return best;
            }

            float breakMask(vec2 cell, float along01, float prob, float len01)
            {
                float rnd = hash21(cell);
                float gapCenter = hash21(cell + 19.71);
                float gap = 1.0 - smoothstep(len01, len01 * 0.4, abs(along01 - gapCenter));
                return mix(1.0, gap, step(rnd, prob));
            }

            vec4 frag(v2f i) 
            {
                vec2 p = i.uv - 0.5;
                p.x *= 1.0; 

                float r = length(p) * 2.0;
                float a = PMWebAngle(p.y, p.x);
                float a01 = fract(a / TAU + 1.0);

                float boundaryNoise = 0.035 * sin(a * 5.0 + hash11(floor(a01 * 9.0)) * TAU)
                                    + 0.020 * sin(a * 13.0 + 1.7);
                float maxR = uMaterial._MaxRadius * (1.0 + boundaryNoise);
                float inside = smoothstep(maxR + 0.025, maxR - 0.008, r) * smoothstep(uMaterial._OriginFade * 0.55, uMaterial._OriginFade, r);

                float vib = sin(uMaterial._Time.y * uMaterial._VibFreq * TAU - r * uMaterial._VibPropDelay * TAU + sin(a * 3.0)) * uMaterial._VibAmp * (1.0 - r);
                float micro = sin(a * uMaterial._MicroWaveFreq + r * 31.0 + uMaterial._Time.y) * uMaterial._MicroWaveAmp;
                float sag = uMaterial._CatenaryAmt * sin(a * 2.0 + 0.7) * r * (1.0 - r);
                float rr = r + vib + micro + sag;

                float spokeId;
                float spokeDist = angleDistanceToSpoke(a01, max(rr, 0.001), spokeId);
                float spokeWidth = uMaterial._RadialWidth * mix(1.0, 1.0 + (hash11(spokeId) - 0.5) * 1.3, uMaterial._WidthVariation);
                float spokes = lineMask(spokeDist, spokeWidth);
                spokes *= breakMask(vec2(spokeId, floor(rr / max(uMaterial._SpokeBreakLen, 0.005))), fract(rr / max(uMaterial._SpokeBreakLen, 0.005)), uMaterial._SpokeBreakProb, 0.24);

                float radialSpacing = max((maxR - uMaterial._OriginFade) / max(uMaterial._SpiralCount, 1.0), 0.001);
                float spacingNoise = (hash11(floor(rr / radialSpacing) + 100.0) - 0.5) * uMaterial._SpiralSpacingVar * radialSpacing;
                float spiralWobble = sin(a * uMaterial._SpokeCount + rr * 9.0) * uMaterial._SpiralIrregular + spacingNoise;
                float spiralCoord = ((rr - uMaterial._OriginFade + spiralWobble) / radialSpacing) - a01; 
                float spiralLineDist = abs(fract(spiralCoord + 0.5) - 0.5) * radialSpacing;
                float spiral = lineMask(spiralLineDist, uMaterial._SpiralWidth);
                float spiralRing = floor(spiralCoord);
                float spiralSeg = floor(a01 * uMaterial._SpokeCount);
                spiral *= breakMask(vec2(spiralRing, spiralSeg), fract(a01 * uMaterial._SpokeCount), uMaterial._SpiralBreakProb, uMaterial._SpiralBreakLen);
                spiral *= smoothstep(uMaterial._OriginFade + 0.03, uMaterial._OriginFade + 0.09, rr);

                float frame = lineMask(abs(r - maxR), uMaterial._RadialWidth * 1.7);
                float hubRings = lineMask(abs(fract(r * 48.0) - 0.5) / 48.0, uMaterial._SpiralWidth * 0.9) * smoothstep(uMaterial._OriginFade * 1.8, uMaterial._OriginFade * 0.65, r);
                float hubSpokes = spokes * smoothstep(uMaterial._OriginFade * 1.7, uMaterial._OriginFade * 0.7, r);
                float hub = max(hubRings, hubSpokes) * 0.85;

                float beadPhase = fract(a01 * uMaterial._BeadDensity + rr * 2.0 + hash11(spiralRing) * 0.37);
                float bead = 1.0 - smoothstep(0.030 * uMaterial._BeadSize, 0.065 * uMaterial._BeadSize, abs(beadPhase - 0.5));
                bead *= mix(spiral, max(spiral, spokes), uMaterial._BeadOnRadial);
                bead *= step(0.58, hash21(vec2(spiralSeg, spiralRing + 55.0)));

                float silk = saturate(max(max(spokes, spiral), max(frame, hub))) * inside;
                float glintDir = abs(dot(normalize(vec3(p, 0.18)), normalize(uMaterial._LightDir.xyz)));
                float glint = pow(saturate(glintDir), 1.0 / max(uMaterial._SpecWidth, 0.02));
                float rim = pow(saturate(r / max(maxR, 0.001)), 2.2) * uMaterial._RimStrength;
                float irid = 0.5 + 0.5 * sin((a01 + r + uMaterial._IridescenceOffset) * TAU * 3.0);

                float intensity = silk * (0.62 + glint * 0.75 + rim * 0.22 + irid * uMaterial._IridescenceStrength) + bead * uMaterial._BeadBrightness;
                float alpha = saturate((silk * uMaterial._BaseAlpha + bead * 0.45) * uMaterial._Appear);
                vec3 col = mix(uMaterial._BaseColor.rgb, uMaterial._HighlightColor.rgb, saturate(glint + bead));
                return vec4(col * intensity, alpha);
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 0) out vec2 pmVuv;
void main() {
appdata pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.uv = pmInuv;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.pos;
pmVuv = pmOutput.uv;
}
