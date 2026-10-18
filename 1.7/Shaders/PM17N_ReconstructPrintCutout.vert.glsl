#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _Color; // @color @default = vec4(1.0, 1.0, 1.0, 1.0)
    vec4 _MainTex_ST; // @default = vec4(0.0, 0.0, 1.0, 1.0)
    vec4 _PM_ScanColor; // @color @default = vec4(0.20000000298023224, 0.8999999761581421, 1.0, 1.0)
    float _Cutoff; // @default = 0.5
    float _PM_AboveAlpha; // @default = 0.0
    float _PM_BelowAlpha; // @default = 1.0
    float _PM_LineSharpness; // @default = 2.0
    float _PM_ScanIntensity; // @default = 2.0
    float _PM_ScanSoftness; // @default = 0.019999999552965164
    float _PM_ScanThickness; // @default = 0.019999999552965164
    float _PM_ScanV; // @default = 0.0
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



            struct appdata
            {
                vec4 vertex ;
                vec2 uv ;
                vec4 color ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv ;
                vec4 color ;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = ((v.uv).xy * uMaterial._MainTex_ST.zw + uMaterial._MainTex_ST.xy);
                o.color = v.color;
                return o;
            }

            vec4 frag (v2f i) 
            {
                vec4 tex = PMTexture(_MainTex, i.uv);
                vec4 col = tex * uMaterial._Color * i.color;

                clip(col.a - uMaterial._Cutoff);

                float v = saturate(i.uv.y);
                float scanV = saturate(uMaterial._PM_ScanV);

                float reveal = smoothstep(scanV - uMaterial._PM_ScanSoftness, scanV + uMaterial._PM_ScanSoftness, v);
                float a = mix(uMaterial._PM_AboveAlpha, uMaterial._PM_BelowAlpha, reveal);

                float dist = abs(v - scanV);
                float edge = uMaterial._PM_ScanThickness + 0.0001;
                float scanLine = 1.0 - smoothstep(uMaterial._PM_ScanThickness, edge, dist);
                scanLine = pow(saturate(scanLine), uMaterial._PM_LineSharpness);

                col.rgb = col.rgb + uMaterial._PM_ScanColor.rgb * (scanLine * uMaterial._PM_ScanIntensity);
                col.a = col.a * a;

                clip(col.a - 0.001);
                return col;
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 2) in vec4 pmIncolor; // @vertex Color optional @default = vec4(1.0)
layout(location = 0) out vec2 pmVuv;
layout(location = 1) out vec4 pmVcolor;
void main() {
appdata pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.uv = pmInuv;
pmInput.color = pmIncolor;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.pos;
pmVuv = pmOutput.uv;
pmVcolor = pmOutput.color;
}
