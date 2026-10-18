#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BreakOrigin; // @default = vec4(0.5, 0.5, 0.0, 0.0)
    vec4 _Color; // @color @default = vec4(0.41999998688697815, 0.7799999713897705, 1.0, 1.0)
    vec4 _Pulse0; // @default = vec4(0.5, 0.5, 0.0, -1.0)
    vec4 _Pulse1; // @default = vec4(0.5, 0.5, 0.0, -1.0)
    vec4 _Pulse2; // @default = vec4(0.5, 0.5, 0.0, -1.0)
    vec4 _Pulse3; // @default = vec4(0.5, 0.5, 0.0, -1.0)
    vec4 _ShardColor; // @color @default = vec4(0.699999988079071, 0.9200000166893005, 1.0, 1.0)
    float _Aspect; // @default = 1.0
    float _BreakActive; // @default = 0.0
    float _BreakCells; // @default = 11.0
    float _BreakProgress; // @default = 0.0
    float _BreakSpread; // @default = 1.2000000476837158
    float _EdgeGlow; // @default = 2.0
    float _HexScale; // @default = 24.0
    float _LineSoftness; // @default = 0.006000000052154064
    float _LineWidth; // @default = 0.017999999225139618
    float _PulseSharp; // @default = 5.0
    float _PulseWidth; // @default = 0.07999999821186066
    float _PulseWobAmp; // @default = 0.3499999940395355
    float _PulseWobFreq; // @default = 18.0
    float _ShardFlyDist; // @default = 1.100000023841858
    float _ShardGlow; // @default = 2.200000047683716
    float _ShardScalePeak; // @default = 1.25
    float _SphereRadius; // @default = 0.5
    float _SphereSoftness; // @default = 0.05999999865889549
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



            struct appdata
            {
                vec4 vertex ;
                vec2 uv     ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv  ;
            };

            float hash11(float n)  { return fract(sin(n) * 43758.5453123); }
            float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
            float hash13(vec3 p)
            {
                p = fract(p * 0.1031);
                p += dot(p, p.yzx + 33.33);
                return fract((p.x + p.y) * p.z);
            }

            vec2 HexGrid(vec2 p, out vec2 o_local)
            {
                const float SQ3 = 1.7320508;

                vec2 axial;
                axial.x = (1.0 / SQ3) * p.x - (1.0 / 3.0) * p.y;
                axial.y = (2.0 / 3.0) * p.y;

                float s  = -axial.x - axial.y;
                float rx = round(axial.x);
                float ry = round(axial.y);
                float rs = round(s);

                float dx = abs(rx - axial.x);
                float dy = abs(ry - axial.y);
                float ds = abs(rs - s);

                if (dx > dy && dx > ds)      rx = -ry - rs;
                else if (dy > ds)            ry = -rx - rs;
                else                         rs = -rx - ry;  

                vec2 hexID = vec2(rx, ry);

                vec2 center;
                center.x = SQ3 * hexID.x + SQ3 * 0.5 * hexID.y;
                center.y = 1.5 * hexID.y;

                o_local = p - center;
                return hexID;
            }

            float HexSDF(vec2 p)
            {
                const float INRAD = 0.8660254; 
                float d0 = abs(p.x);
                float d1 = abs(0.5 * p.x + 0.8660254 * p.y);
                float d2 = abs(0.5 * p.x - 0.8660254 * p.y);
                return max(max(d0, d1), d2) - INRAD;
            }

            float HexLineMask(vec2 p, float lw, float soft)
            {
                float d = HexSDF(p);
                
                float mask = smoothstep(-lw - soft, -lw,      d)   
                           * (1.0 - smoothstep(-soft, soft,   d)); 
                return saturate(mask);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = v.uv;
                return o;
            }

            vec4 frag(v2f i) 
            {
                vec2 uv = i.uv; 

                float aspect = max(0.1, uMaterial._Aspect);
                
                vec2 p = (uv - 0.5) * vec2(aspect, 1.0) * uMaterial._HexScale;

                vec2 local;
                vec2 hexID = HexGrid(p, local);

                const float SQ3 = 1.7320508;
                vec2 hexCenter;
                hexCenter.x = SQ3 * hexID.x + SQ3 * 0.5 * hexID.y;
                hexCenter.y = 1.5 * hexID.y;

                float outline = HexLineMask(local, uMaterial._LineWidth * uMaterial._HexScale * 0.5,
                                                   uMaterial._LineSoftness * uMaterial._HexScale * 0.5);

                vec4 pulses[4] = { uMaterial._Pulse0, uMaterial._Pulse1, uMaterial._Pulse2, uMaterial._Pulse3 };
                float pulseVis = 0.0;

                for (int pi = 0; pi < 4; pi++)
                {
                    vec4 pv = pulses[pi];
                    if (pv.w < 0.0) continue;   

                    vec2 hitUV = pv.xy;                        
                    float  t     = saturate(pv.z);               
                    float  t2    = saturate(pv.w);               

                    vec2 hitP = (hitUV - 0.5) * vec2(aspect, 1.0) * uMaterial._HexScale;

                    float dist = length(p - hitP) / uMaterial._HexScale; 

                    float waveFront = t * 1.414; 
                    float distFromFront = abs(dist - waveFront);
                    float band = 1.0 - smoothstep(0.0, uMaterial._PulseWidth, distFromFront);
                    band = pow(saturate(band), max(1.0, uMaterial._PulseSharp));

                    float angle = atan((p.y - hitP.y), (p.x - hitP.x));
                    float wob   = 0.5 + 0.5 * sin(angle * uMaterial._PulseWobFreq - t * 6.2832 * 3.0);
                    float pvis  = band * outline * (uMaterial._EdgeGlow * 0.75 + 0.4) * (1.0 - uMaterial._PulseWobAmp + uMaterial._PulseWobAmp * wob);

                    pvis *= (1.0 - smoothstep(0.75, 1.0, t));

                    pulseVis = max(pulseVis, pvis);
                }

                float breakProgress = saturate(uMaterial._BreakProgress);
                float brkGate       = saturate(uMaterial._BreakActive);
                
                float brkVis        = brkGate * (0.35 + 0.65 * sqrt(breakProgress));
                float brk           = brkGate * breakProgress;
                float breakVis = 0.0;
                vec3 shardCol = uMaterial._ShardColor.rgb;

                if (brk > 0.001)
                {
                    
                    vec2 originP = (uMaterial._BreakOrigin.xy - 0.5) * vec2(aspect, 1.0) * uMaterial._HexScale;

                    float cellRand  = hash12(hexID);
                    float cellRand2 = hash12(hexID * 1.618 + 0.5); 

                    float distToOrigin = length(hexCenter - originP) / uMaterial._HexScale;

                    float waveFront = uMaterial._BreakProgress * uMaterial._BreakSpread;
                    float fadeStart = distToOrigin + cellRand * 0.12;
                    float fadeEnd   = fadeStart + 0.07;

                    float cellPhase = saturate((waveFront - fadeStart) / max(0.001, fadeEnd - fadeStart));
                    float cellAlive = 1.0 - cellPhase; 

                    vec2 flyDir = hexCenter - originP;
                    float  flyDirLen = length(flyDir);
                    if (flyDirLen < 0.001) flyDir = vec2(cellRand - 0.5, cellRand2 - 0.5);
                    flyDir = normalize(flyDir);
                    
                    float rotAngle = (cellRand2 - 0.5) * 0.88; 
                    vec2 flyDirR;
                    flyDirR.x = flyDir.x * cos(rotAngle) - flyDir.y * sin(rotAngle);
                    flyDirR.y = flyDir.x * sin(rotAngle) + flyDir.y * cos(rotAngle);

                    float flyEase   = 1.0 - (1.0 - cellPhase) * (1.0 - cellPhase);
                    float flyAmount = flyEase * uMaterial._ShardFlyDist;
                    
                    vec2 localDisplaced = local - flyDirR * flyAmount;

                    float scaleCurve;
                    if (cellPhase < 0.25)
                        scaleCurve = 1.0 + (cellPhase / 0.25) * (uMaterial._ShardScalePeak - 1.0);       
                    else
                        scaleCurve = uMaterial._ShardScalePeak * (1.0 - (cellPhase - 0.25) / 0.75);      
                    scaleCurve = max(0.001, scaleCurve);

                    vec2 localScaled = localDisplaced / scaleCurve;

                    float lw   = uMaterial._LineWidth   * uMaterial._HexScale * 0.5;
                    float soft = uMaterial._LineSoftness * uMaterial._HexScale * 0.5;
                    float outlineBreak = HexLineMask(localScaled, lw, soft);

                    float hexInner = saturate(1.0 - smoothstep(-0.05, 0.0, HexSDF(localScaled)));
                    float shardFill = hexInner * 0.55 * scaleCurve; 

                    float nearFade = smoothstep(fadeStart - 0.25, fadeStart, waveFront)
                                   * (1.0 - smoothstep(fadeStart, fadeEnd, waveFront));
                    float edgeGlow = (nearFade * 1.4 + cellPhase * 0.6) * outlineBreak;

                    vec3 nq = vec3(hexCenter * (uMaterial._BreakCells / uMaterial._HexScale), uMaterial._BreakProgress * 2.5);
                    float  e1 = hash13(floor(nq));
                    float  e2 = hash13(floor(nq + vec3(1.7, 0.9, 0.3)));
                    float  crack     = abs(e1 - e2);
                    float  crackMask = smoothstep(0.08, 0.22, crack) * (1.0 - smoothstep(0.3, 0.5, crack));

                    float shardEdge = edgeGlow * uMaterial._ShardGlow + crackMask * 0.35 * nearFade + shardFill;
                    
                    breakVis = saturate(shardEdge * scaleCurve * brkVis);
                }

                float totalVis = max(pulseVis, breakVis);

                if (totalVis < 0.0001 && uMaterial._BreakActive < 0.5)
                    totalVis = 0.0;

                vec3 col = uMaterial._Color.rgb * (0.5 + 1.5 * pulseVis);
                col = min(col, vec3(1.5, 1.8, 2.0)); 
                col = mix(col, shardCol, saturate(brk * breakVis * 2.0));

                float alpha = totalVis * uMaterial._Color.a;
                
                vec2 uvCenter = (uv - 0.5) * vec2(aspect, 1.0);
                float radial = length(uvCenter);
                float circleMask = 1.0 - smoothstep(uMaterial._SphereRadius - uMaterial._SphereSoftness, uMaterial._SphereRadius, radial);
                alpha *= saturate(circleMask);
                return vec4(col, alpha);
            }
            
layout(location = 0) in vec2 pmVuv;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.uv = pmVuv;
outColor = frag(pmInput);
}
