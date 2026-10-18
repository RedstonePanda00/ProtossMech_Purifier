#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _RingInnerColor; // @color @default = vec4(1.0, 0.949999988079071, 0.7799999713897705, 1.0)
    vec4 _RingOuterColor; // @color @default = vec4(1.0, 0.3499999940395355, 0.03999999910593033, 1.0)
    vec4 _Time;
    vec4 _VoidColor; // @color @default = vec4(0.0, 0.0, 0.0, 1.0)
    float _BlackHoleShrink; // @default = 0.0
    float _CoreRadius; // @default = 0.24500000476837158
    float _LayerAlpha; // @default = 1.0
    float _OutputRgbBoost; // @default = 1.149999976158142
    float _RingAlpha; // @default = 0.8999999761581421
    float _RingIntensity; // @default = 5.0
    float _RingWidth; // @default = 0.029999999329447746
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
                vec2 p = i.uv - 0.5;
                float dist = length(p);
                float shrink = saturate(uMaterial._BlackHoleShrink);
                float birth = smoothstep(0.10, 0.18, t);
                float open = birth * (1.0 - smoothstep(0.0, 1.0, shrink));
                float radius = max(uMaterial._CoreRadius * birth * (1.0 - shrink), 0.002);

                float core = 1.0 - smoothstep(radius - 0.004, radius + 0.006, dist);
                float ring1 = exp(-pow((dist - radius * 1.06) / max(uMaterial._RingWidth, 1e-4), 2.0));
                float ring2 = exp(-pow((dist - radius * 1.32) / max(uMaterial._RingWidth * 0.75, 1e-4), 2.0)) * 0.18;
                float ring3 = exp(-pow((dist - radius * 1.65) / max(uMaterial._RingWidth * 0.55, 1e-4), 2.0)) * 0.08;
                float ring4 = exp(-pow((dist - radius * 2.08) / max(uMaterial._RingWidth * 0.42, 1e-4), 2.0)) * 0.035;
                float ripple = 0.78 + 0.22 * noise(p * 28.0 + uMaterial._Time.y * 0.8);
                float ring = (ring1 + ring2 + ring3 + ring4) * ripple * open;

                vec3 ringColor = mix(uMaterial._RingInnerColor.rgb, uMaterial._RingOuterColor.rgb, smoothstep(radius, radius * 1.45, dist));
                vec3 rgb = uMaterial._VoidColor.rgb * core + ringColor * ring * uMaterial._RingIntensity;
                float alpha = saturate(core * open + ring * uMaterial._RingAlpha) * uMaterial._LayerAlpha;
                rgb = rgb * uMaterial._OutputRgbBoost;
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
