#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _Color; // @color @default = vec4(0.1599999964237213, 0.800000011920929, 1.0, 0.7799999713897705)
    float _Frame; // @default = 0.0
    float _Hit; // @default = 0.0
    float _Phase; // @default = 0.0
    float _Reveal; // @default = 1.0
    float _Seed; // @default = 0.0
    float _Visibility; // @default = 1.0
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



            struct appdata { vec4 vertex ; vec2 uv ; };
            struct v2f { vec4 vertex ; vec2 uv ; };
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            float noise(vec2 p)
            {
                vec3 n = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
                n += dot(n, n.yzx + 33.33);
                return fract((n.x + n.y) * n.z);
            }
            vec4 frag(v2f i) 
            {
                float band = floor(i.uv.y * 42.0);
                float n = noise(vec2(band + uMaterial._Seed, uMaterial._Frame));
                float tear = step(0.62, n) * (n - 0.5) * uMaterial._Hit * 0.11;
                vec2 uv = i.uv + vec2(tear, 0);
                vec4 src = PMTexture(_MainTex, uv);
                
                float inside = step(0, uv.x) * step(uv.x, 1) * step(0, uv.y) * step(uv.y, 1);
                float scan = 0.70 + 0.30 * smoothstep(0.12, 0.34, fract(uv.y * 96.0 - uMaterial._Phase * 2.0));
                float sweep = pow(saturate(1.0 - abs(fract(uv.y - uMaterial._Phase * 0.20) - 0.5) * 16.0), 2.0);
                float flicker = 0.94 + 0.06 * noise(vec2(uMaterial._Seed, uMaterial._Frame));
                float dropout = 1.0 - uMaterial._Hit * step(n, 0.16) * 0.78;
                float dissolveNoise = noise(floor(uv * 110) + vec2(uMaterial._Seed, uMaterial._Frame));
                float dissolve = step(dissolveNoise * 0.999, uMaterial._Visibility);
                float reveal = step(i.uv.y, uMaterial._Reveal * 1.02);
                float a = src.a * uMaterial._Color.a * scan * flicker * dropout * dissolve * reveal * uMaterial._Visibility * inside;
                float luminance = dot(src.rgb, vec3(0.299, 0.587, 0.114));
                vec3 color = uMaterial._Color.rgb * (0.34 + 0.76 * luminance);
                color += vec3(0.12, 0.22, 0.25) * sweep;
                color = mix(color, vec3(0.75, 0.95, 1), uMaterial._Hit * 0.42);
                return vec4(color, a);
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
