#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    float _Age; // @default = 0.0
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



 struct appdata {vec4 vertex;vec2 uv;};
 struct v2f {vec4 pos;vec2 uv;};
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
 vec4 frag(v2f i) {
 vec4 source=PMTexture(_MainTex,i.uv);float a=source.a;
 float surface=.22+.78*smoothstep(.08,.8,dot(source.rgb,vec3(.299,.587,.114)));
 vec2 px=vec4(1.0 / vec2(textureSize(_MainTex, 0)), vec2(textureSize(_MainTex, 0))).xy*2;
 float nearA=max(max(PMTexture(_MainTex,i.uv+vec2(px.x,0)).a,PMTexture(_MainTex,i.uv-vec2(px.x,0)).a),max(PMTexture(_MainTex,i.uv+vec2(0,px.y)).a,PMTexture(_MainTex,i.uv-vec2(0,px.y)).a));
 float rim=saturate(nearA-a);
 float fade=pow(saturate(1-uMaterial._Age/.65),1.3);
 float peak=smoothstep(0,.035,uMaterial._Age)*(1-smoothstep(.065,.17,uMaterial._Age));
 vec2 grid=i.uv*80+vec2(uMaterial._Age*3,-uMaterial._Age*12);vec2 cell=floor(grid);float h=hash(cell);
 vec2 q=fract(grid)-.5;float dotShape=pow(saturate(1-length(q)*2.4),3);
 float flicker=.4+.6*pow(saturate(sin(uMaterial._Age*37+h*25)),2);
 float flecks=step(.69,h)*dotShape*flicker;
 float filament=pow(saturate(sin(i.uv.y*110+i.uv.x*70+uMaterial._Age*26)),20)*step(.5,hash(floor(i.uv*24)));
 vec3 violet=vec3(.40,.30,1.0),blue=vec3(.38,.65,1.0);
 vec3 tint=mix(violet,blue,saturate(i.uv.y));
 vec3 color=mix(tint,vec3(1,.98,1),saturate(peak+flecks*.6));
 float glow=(a*(peak*.35*surface+fade*(.025+flecks*.85+filament*.22))+rim*fade*.45);
 return vec4(color*1.3,glow);
 }
 
layout(location = 0) in vec2 pmVuv;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.uv = pmVuv;
outColor = frag(pmInput);
}
