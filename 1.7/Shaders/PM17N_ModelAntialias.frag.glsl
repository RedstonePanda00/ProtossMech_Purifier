#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _ScreenParams;
} uMaterial;
layout(set = 2, binding = 1) uniform sampler2D _Grab_PMModelScene;
layout(set = 2, binding = 2) uniform sampler2D _ModelMask;

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

   struct v2f {vec4 pos;vec4 screen;};
   v2f vert(appdata_base v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.screen=ComputeGrabScreenPos(o.pos);return o;}
   float Luma(vec3 c) { return dot(c,vec3(.299,.587,.114)); }
   vec4 frag(v2f i)
   {
    vec2 uv=i.screen.xy/i.screen.w, pixel=1/uMaterial._ScreenParams.xy;
    vec4 original=texture(_Grab_PMModelScene,uv);
    float mask=PMTexture(_ModelMask,uv).r;
    mask=max(mask,PMTexture(_ModelMask,uv+pixel*vec2(1,0)).r);
    mask=max(mask,PMTexture(_ModelMask,uv+pixel*vec2(-1,0)).r);
    mask=max(mask,PMTexture(_ModelMask,uv+pixel*vec2(0,1)).r);
    mask=max(mask,PMTexture(_ModelMask,uv+pixel*vec2(0,-1)).r);
    clip(mask-.5);
    float nw=Luma(texture(_Grab_PMModelScene,uv+pixel*vec2(-1,-1)).rgb);
    float ne=Luma(texture(_Grab_PMModelScene,uv+pixel*vec2(1,-1)).rgb);
    float sw=Luma(texture(_Grab_PMModelScene,uv+pixel*vec2(-1,1)).rgb);
    float se=Luma(texture(_Grab_PMModelScene,uv+pixel*vec2(1,1)).rgb);
    float mid=Luma(original.rgb);
    float lo=min(mid,min(min(nw,ne),min(sw,se)));
    float hi=max(mid,max(max(nw,ne),max(sw,se)));
    if(hi-lo<max(.025,hi*.10)) return original;
    vec2 direction=vec2(-((nw+ne)-(sw+se)),(nw+sw)-(ne+se));
    float reduce=max((nw+ne+sw+se)*.03125,.0078125);
    direction=clamp(direction/(min(abs(direction.x),abs(direction.y))+reduce),-4,4)*pixel;
    vec3 a=.5*(texture(_Grab_PMModelScene,uv+direction*(-1.0/6)).rgb+texture(_Grab_PMModelScene,uv+direction*(1.0/6)).rgb);
    vec3 b=a*.5+.25*(texture(_Grab_PMModelScene,uv-direction*.5).rgb+texture(_Grab_PMModelScene,uv+direction*.5).rgb);
    float l=Luma(b);
    return vec4(l<lo||l>hi?a:b,original.a);
   }
 
layout(location = 0) in vec4 pmVscreen;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.screen = pmVscreen;
outColor = frag(pmInput);
}
