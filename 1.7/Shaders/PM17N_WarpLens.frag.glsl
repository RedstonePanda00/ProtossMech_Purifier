#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _LensColor; // @color @default = vec4(1.0, 0.7799999713897705, 0.550000011920929, 1.0)
    vec4 _OuterColor; // @color @default = vec4(0.5, 0.75, 1.0, 1.0)
    vec4 _Time;
    float _ArcHeight; // @default = 0.1599999964237213
    float _ArcInset; // @default = 0.18000000715255737
    float _ArcIntensity; // @default = 1.7999999523162842
    float _ArcRadius; // @default = 0.25999999046325684
    float _ArcThickness; // @default = 0.04500000178813934
    float _BlackHoleShrink; // @default = 0.0
    float _FlowSpeed; // @default = 1.600000023841858
    float _HaloStrength; // @default = 0.3499999940395355
    float _LayerAlpha; // @default = 1.0
    float _LayerSign; // @default = 1.0
    float _ToneMapStrength; // @default = 0.11999999731779099
    float _WarpProgress; // @default = 0.550000011920929
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
                vec2 uv ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv ;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float hash12(vec2 p)
            {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            float noise(vec2 p)
            {
                vec2 i = floor(p);
                vec2 f = fract(p);
                vec2 u = f * f * (3.0 - 2.0 * f);
                float a = hash12(i);
                float b = hash12(i + vec2(1, 0));
                float c = hash12(i + vec2(0, 1));
                float d = hash12(i + vec2(1, 1));
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

            vec4 frag(v2f i) 
            {
                float t = saturate(uMaterial._WarpProgress);
                float reveal = smoothstep(0.22, 0.36, t) * (1.0 - smoothstep(0.0, 1.0, saturate(uMaterial._BlackHoleShrink)));
                vec2 p = i.uv - 0.5;
                float signY = uMaterial._LayerSign >= 0 ? 1.0 : -1.0;
                float y = p.y * signY;

                float ax = abs(p.x);
                float arcReach = mix(0.76, 0.28, saturate(uMaterial._ArcInset));
                float fadeStart = max(arcReach - 0.16, 0.06);
                float nearCore = 1.0 - smoothstep(fadeStart, arcReach, ax);
                float archX = saturate(ax / max(fadeStart, 1e-4));
                float archCenterY = uMaterial._ArcHeight * (1.0 - archX * archX);
                float archD = abs(y - archCenterY);
                float width = uMaterial._ArcThickness * (1.0 + 0.28 * smoothstep(0.0, 0.55, ax));
                float arch = exp(-pow(archD / max(width, 1e-4), 2.0)) * nearCore;
                float archHalo = exp(-pow(archD / max(width * 2.8, 1e-4), 2.0)) * nearCore * uMaterial._HaloStrength;

                float radial = length(vec2(p.x, y * 1.25));
                float closeRing = exp(-pow((radial - uMaterial._ArcRadius) / max(width * 0.8, 1e-4), 2.0));
                closeRing *= smoothstep(0.01, 0.10, y) * nearCore;
                float arc = (arch * 0.8 + archHalo + closeRing * 0.45) * smoothstep(-0.02, 0.08, y);

                float flow = noise(vec2(p.x * 18.0 + uMaterial._Time.y * uMaterial._FlowSpeed, y * 6.0)) * 0.5
                    + noise(vec2(p.x * 36.0 + uMaterial._Time.y * uMaterial._FlowSpeed * 1.3, y * 12.0)) * 0.35
                    + noise(vec2(p.x * 72.0 + uMaterial._Time.y * uMaterial._FlowSpeed * 1.6, y * 24.0)) * 0.15;
                float streak = 0.45 + 0.55 * pow(flow, 2.0);
                vec3 rgb = mix(uMaterial._LensColor.rgb, uMaterial._OuterColor.rgb, smoothstep(0.2, 0.7, abs(p.x))) * arc * streak * uMaterial._ArcIntensity * reveal;
                rgb = rgb / (1.0 + max(rgb.r, max(rgb.g, rgb.b)) * uMaterial._ToneMapStrength);
                float alpha = saturate(arc * 0.55 * reveal) * uMaterial._LayerAlpha;
                return vec4(rgb, alpha);
            }
            
layout(location = 0) in vec2 pmVuv;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.uv = pmVuv;
outColor = frag(pmInput);
}
