#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    float _Aspect; // @default = 1.0
    float _Frame; // @default = 1.0
    float _Progress; // @default = 1.0
} uMaterial;
layout(set = 2, binding = 1) uniform sampler2D _MainTex;

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



            struct appdata { vec4 vertex ; vec2 uv ; vec4 color ; };
            struct v2f { vec4 vertex ; vec2 uv ; vec4 color ; };
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }
            float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
            float boundary(float group, float index, float count)
            {
                if (index <= 0) return 0;
                if (index >= count) return count;
                return index + (hash(vec2(group * 17 + index, 71)) - 0.5) * 0.7;
            }
            vec4 sampleShell(vec2 uv)
            {
                float inside = step(0, uv.y) * step(uv.y, 1);
                return mix(vec4(0.005,0.006,0.008,0.96), PMTexture(_MainTex, uv), uMaterial._Frame) * inside;
            }
            vec4 frag(v2f i) 
            {
                vec2 uv = i.uv;

                float position = min(uv.x * 32, 31.99999);
                float group = floor(position);
                float density = hash(vec2(group, 59));
                
                float count = density > 0.85 ? 3 : 7 + floor(density / 0.85 * 7);
                float within = fract(position) * count;
                float index = floor(within);
                if (within < boundary(group, index, count)) index -= 1;
                else if (within >= boundary(group, index + 1, count)) index += 1;
                float row = group * 17 + index;
                float coarse = hash(vec2(group, 17));
                float fine = hash(vec2(row, 43));
                float seed = mix(coarse, fine, 0.32);
                float local = saturate((uMaterial._Progress - seed * 0.16) / (1 - seed * 0.16));
                float settle = smoothstep(0, 1, local);
                float distortion = 1 - settle;
                float scale = mix(0.25 + seed * 1.45, 1, settle);
                float shift = (coarse - 0.5) * 0.52 * distortion;
                shift += sin(local * 6.283 + seed * 5) * distortion * local * 0.08;
                float sourceY = (uv.y - 0.5 - shift) / scale + 0.5;
                
                float pivot = mix(0.12, 0.88, coarse);
                float stretch = distortion * (0.3 + fine * 0.4);
                float draggedY = mix(sourceY, pivot, stretch);
                vec2 source = vec2(uv.x, mix(sourceY, draggedY,
                    smoothstep(0.05, 0.35, abs(sourceY - pivot)) * distortion));
                vec4 col = sampleShell(source);
                float trail = distortion * 0.035 * (coarse < 0.5 ? -1 : 1);
                
                vec4 smear = sampleShell(source - vec2(0, trail)) * 0.5
                    + sampleShell(source - vec2(0, trail * 2)) * 0.3
                    + sampleShell(source - vec2(0, trail * 3)) * 0.2;
                col = mix(col, smear, distortion * 0.42);
                col.a *= smoothstep(0, 0.18, local);
                return col * i.color;
            }
            
layout(location = 1) in vec2 pmVuv;
layout(location = 0) in vec4 pmVcolor;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.vertex = gl_FragCoord;
pmInput.uv = pmVuv;
pmInput.color = pmVcolor;
outColor = frag(pmInput);
}
