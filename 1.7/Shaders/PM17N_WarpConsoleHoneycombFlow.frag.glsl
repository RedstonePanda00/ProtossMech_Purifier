#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BaseColor; // @color @default = vec4(0.004000000189989805, 0.006000000052154064, 0.012000000104308128, 1.0)
    vec4 _GlowColor; // @color @default = vec4(1.0, 0.550000011920929, 0.03999999910593033, 1.0)
    vec4 _LineColor; // @color @default = vec4(0.10000000149011612, 0.12999999523162842, 0.18000000715255737, 1.0)
    vec4 _Time;
    vec4 _VignetteColor; // @color @default = vec4(0.0, 0.0, 0.0, 1.0)
    float _Alpha; // @default = 1.0
    float _Aspect; // @default = 1.0
    float _GlowStrength; // @default = 2.5
    float _LineSoftness; // @default = 0.004999999888241291
    float _LineWidth; // @default = 0.019999999552965164
    float _Scale; // @default = 12.0
    float _Vignette; // @default = 0.550000011920929
    float _WaveFrequency; // @default = 2.799999952316284
    float _WaveSharpness; // @default = 0.18000000715255737
    float _WaveSpeed; // @default = 0.550000011920929
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
                vec4 color  ;
            };

            struct v2f
            {
                vec4 pos   ;
                vec2 uv    ;
                vec4 color ;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos   = UnityObjectToClipPos(v.vertex);
                o.uv    = v.uv;
                o.color = v.color;
                return o;
            }

            vec2 HexGrid(vec2 p, out vec2 o_local)
            {
                
                const float SQ3 = 1.7320508;

                vec2 axial;
                axial.x = (1.0/1.7320508) * p.x - (1.0/3.0) * p.y;
                axial.y = (2.0/3.0) * p.y;

                vec2 r2 = vec2(axial.x, axial.y);
                float  s  = -axial.x - axial.y;

                float rx = round(r2.x);
                float ry = round(r2.y);
                float rs = round(s);

                float dx = abs(rx - r2.x);
                float dy = abs(ry - r2.y);
                float ds = abs(rs - s);

                if (dx > dy && dx > ds)       rx = -ry - rs;
                else if (dy > ds)             ry = -rx - rs;
                else                          rs = -rx - ry;

                vec2 hexID = vec2(rx, ry);

                vec2 center;
                center.x = SQ3 * hexID.x + SQ3 * 0.5 * hexID.y;
                center.y = 1.5 * hexID.y;

                o_local = p - center;
                return hexID;
            }

            float HexSDF(vec2 p)
            {
                const float INRADIUS = 0.8660254; 
                float d0 = abs(p.x);
                float d1 = abs(0.5 * p.x + 0.8660254 * p.y);
                float d2 = abs(0.5 * p.x - 0.8660254 * p.y);
                return max(max(d0, d1), d2) - INRADIUS;
            }

            vec4 frag(v2f i) 
            {
                vec2 uv    = i.uv;
                float  t     = uMaterial._Time.y;
                float  aspect= max(0.25, uMaterial._Aspect);

                vec2 p = (uv - 0.5) * vec2(aspect, 1.0) * uMaterial._Scale;

                vec2 local;
                vec2 hexID = HexGrid(p, local);

                float d = HexSDF(local);

                float lineMask = smoothstep(-uMaterial._LineWidth - uMaterial._LineSoftness, -uMaterial._LineWidth, d)  
                               * (1.0 - smoothstep(-uMaterial._LineSoftness, uMaterial._LineSoftness, d));    
                lineMask = saturate(lineMask);

                const float SQ3 = 1.7320508;
                vec2 center_px;
                center_px.x = SQ3 * hexID.x + SQ3 * 0.5 * hexID.y;
                center_px.y = 1.5 * hexID.y;
                float hexDist = length(center_px) / uMaterial._Scale;

                float phase     = hexDist * uMaterial._WaveFrequency * 6.2831853
                                - t * uMaterial._WaveSpeed * 6.2831853;
                float cosVal    = cos(phase) * 0.5 + 0.5;
                float waveCrest = smoothstep(1.0 - uMaterial._WaveSharpness, 1.0, cosVal);
                float energy    = waveCrest * lineMask;

                vec3 rgb = uMaterial._BaseColor.rgb;
                rgb = mix(rgb, uMaterial._LineColor.rgb, lineMask);
                rgb += uMaterial._GlowColor.rgb * energy * uMaterial._GlowStrength;

                float uvDist = distance(uv, 0.5);
                float vigAmt = smoothstep(0.20, 0.78, uvDist) * uMaterial._Vignette;
                rgb = mix(rgb, uMaterial._VignetteColor.rgb, saturate(vigAmt));

                vec4 col;
                col.rgb = rgb * i.color.rgb;
                col.a   = uMaterial._Alpha * i.color.a;
                return col;
            }
            
layout(location = 1) in vec2 pmVuv;
layout(location = 0) in vec4 pmVcolor;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.uv = pmVuv;
pmInput.color = pmVcolor;
outColor = frag(pmInput);
}
