#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _MainTex_ST; // @default = vec4(0.0, 0.0, 1.0, 1.0)
    float _Cutoff; // @default = 0.10000000149011612
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

struct appdata_base {vec4 vertex;vec3 normal;vec4 texcoord;};

   struct v2f {vec4 pos;vec2 uv;};
   v2f vert(appdata_base v) {v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=((v.texcoord).xy * uMaterial._MainTex_ST.zw + uMaterial._MainTex_ST.xy);return o;}
   vec4 frag(v2f i) {clip(PMTexture(_MainTex,i.uv).a-uMaterial._Cutoff);return vec4(1.0);}
  
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 1) in vec3 pmInnormal; // @vertex Normal optional @default = vec4(0,1,0,0)
layout(location = 3) in vec4 pmIntexcoord; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 0) out vec2 pmVuv;
void main() {
appdata_base pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.normal = pmInnormal;
pmInput.texcoord = pmIntexcoord;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.pos;
pmVuv = pmOutput.uv;
}
