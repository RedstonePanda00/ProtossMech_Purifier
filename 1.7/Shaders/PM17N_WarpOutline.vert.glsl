#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BuildingOutlineColor; // @color @default = vec4(0.0, 0.949999988079071, 1.0, 1.0)
    vec4 _Time;
    float _BuildingOutlineProgress; // @default = 0.0
    float _BuildingOutlineThickness; // @default = 3.0
    float _LayerAlpha; // @default = 1.0
} uMaterial;
layout(set = 2, binding = 1) uniform sampler2D _BuildingTex;

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

            vec4 frag(v2f i) 
            {
                vec2 px = vec4(1.0 / vec2(textureSize(_BuildingTex, 0)), vec2(textureSize(_BuildingTex, 0))).xy * uMaterial._BuildingOutlineThickness;
                float centerA = PMTexture(_BuildingTex, i.uv).a;
                float maxA = centerA;
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2( px.x, 0)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2(-px.x, 0)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2(0,  px.y)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2(0, -px.y)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2( px.x,  px.y)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2(-px.x,  px.y)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2( px.x, -px.y)).a);
                maxA = max(maxA, PMTexture(_BuildingTex, i.uv + vec2(-px.x, -px.y)).a);

                float outline = saturate(maxA - centerA * 0.35);
                float innerTrace = centerA * 0.18;
                vec2 d = abs(i.uv - 0.5) * 2.0;
                float centerDist = max(d.x, d.y);
                float revealEdge = saturate(uMaterial._BuildingOutlineProgress);
                float reveal = 1.0 - smoothstep(revealEdge, revealEdge + 0.02, centerDist);

                float pulse = 0.75 + 0.25 * sin(uMaterial._Time.y * 7.0);
                float alpha = saturate(outline + innerTrace) * reveal * uMaterial._LayerAlpha;
                vec3 color = uMaterial._BuildingOutlineColor.rgb * (1.4 + outline * 1.8 * pulse);
                return vec4(saturate(color), alpha);
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
