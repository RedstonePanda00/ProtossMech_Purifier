#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    float _Age; // @default = 0.0
    float _Seed; // @default = 0.0
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



  struct appdata { vec4 vertex; vec2 uv; };
  struct v2f { vec4 pos; vec2 uv; };
  v2f vert(appdata v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; return o; }
  float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))+uMaterial._Seed*.173)*43758.5453); }
  vec4 frag(v2f i)
  {
   float alpha=PMTexture(_MainTex,i.uv).a;
   vec2 grid=i.uv*58+vec2(sin(uMaterial._Age*1.8)*.3,-uMaterial._Age*5.5);
   vec2 cell=floor(grid), q=fract(grid)-.5;
   float h=hash(cell);
   float ember=pow(saturate(1-length(q*vec2(2.5,1.2))*2.2),2.2)*step(.74,h);
   float flicker=.45+.55*pow(saturate(sin(uMaterial._Age*17+h*31)),2);
   float glow=alpha*(.025+ember*flicker*.8);
   vec3 red=mix(vec3(1,.025,.018),vec3(1,.28,.12),ember*.4);
   return vec4(red,glow);
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
