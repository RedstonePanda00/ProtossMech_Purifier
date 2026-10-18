#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _CoolColor; // @color @default = vec4(0.550000011920929, 0.800000011920929, 1.0, 1.0)
    vec4 _HotColor; // @color @default = vec4(1.0, 0.9599999785423279, 0.7200000286102295, 1.0)
    vec4 _Time;
    vec4 _WarmColor; // @color @default = vec4(1.0, 0.36000001430511475, 0.03999999910593033, 1.0)
    float _BlackHoleShrink; // @default = 0.0
    float _DepthSoftness; // @default = 0.07999999821186066
    float _DiskBrightness; // @default = 12.0
    float _DiskThickness; // @default = 0.14000000059604645
    float _DopplerCamAzimuth; // @default = -1000.0
    float _DopplerStrength; // @default = 0.44999998807907104
    float _FlowSpeed; // @default = 2.4000000953674316
    float _FootprintMax; // @default = 7.0
    float _FrontBridgeStrength; // @default = 0.75
    float _HotRimBoost; // @default = 4.5
    float _InnerRadius; // @default = 0.1599999964237213
    float _LayerAlpha; // @default = 1.0
    float _LayerSign; // @default = 1.0
    float _OuterRadius; // @default = 0.8199999928474426
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
                vec3 normal ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv ;
                vec3 worldP ;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldP = mul(unity_ObjectToWorld, v.vertex).xyz;
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

            float fbm(vec2 p)
            {
                float v = 0;
                float a = 0.5;
                
                for (int k = 0; k < 4; k++)
                {
                    v += noise(p) * a;
                    p = p * 2.03 + 17.3;
                    a *= 0.5;
                }
                return v;
            }

            vec4 frag(v2f i) 
            {
                float t = saturate(uMaterial._WarpProgress);
                float reveal = smoothstep(0.18, 0.32, t) * (1.0 - smoothstep(0.0, 1.0, saturate(uMaterial._BlackHoleShrink)));
                vec2 p = i.uv - 0.5;

                float thick = max(uMaterial._DiskThickness, 1e-4);
                float inner = uMaterial._InnerRadius;
                float outer = uMaterial._OuterRadius;

                vec2 diskP = vec2(p.x, p.y / thick);
                float r = length(diskP);
                float theta = atan(diskP.y, diskP.x);
                float radial01 = saturate((r - inner) / max(outer - inner, 1e-4));

                float ring = smoothstep(inner, inner + 0.035, r) * (1.0 - smoothstep(outer - 0.13, outer + 0.06, r));
                float verticalCore = exp(-pow(abs(p.y) / max(thick * 0.56, 1e-4), 1.24));
                float verticalMist = exp(-pow(abs(p.y) / max(thick * 1.35, 1e-4), 2.0)) * 0.55;

                vec3 objWOrigin = vec3(push.modelMatrix[3][0], push.modelMatrix[3][1], push.modelMatrix[3][2]);
                vec2 wRel = i.worldP.xz - objWOrigin.xz;
                float phiW = atan(wRel.y, wRel.x);
                float phiV = uMaterial._DopplerCamAzimuth > -900.0 ? uMaterial._DopplerCamAzimuth : phiW + 0.78539816;

                float depth = sin(theta - phiV);
                float frontMask = smoothstep(-uMaterial._DepthSoftness, uMaterial._DepthSoftness, depth);
                float backMask = 1.0 - frontMask;
                float layerMask = uMaterial._LayerSign >= 0.0 ? frontMask : backMask;

                float bridgeRadial = smoothstep(inner * 0.86, inner * 1.03, r)
                    * (1.0 - smoothstep(inner * 1.18, inner * 1.72, r));
                float bridge = exp(-pow(abs(p.y) / max(thick * 0.19, 1e-4), 2.0))
                    * bridgeRadial
                    * frontMask * uMaterial._FrontBridgeStrength;

                float spin = uMaterial._Time.y * uMaterial._FlowSpeed * mix(1.85, 0.45, radial01);
                float orbitTheta = theta - spin;
                float flow = fbm(vec2(orbitTheta * 2.2, radial01 * 7.2 - uMaterial._Time.y * uMaterial._FlowSpeed * 0.18));
                float fibers = fbm(vec2(orbitTheta * 5.4 + 11.0, radial01 * 13.5 + flow * 1.25));
                float streak = smoothstep(0.16, 0.9, flow * 0.58 + fibers * 0.62);
                float hotRim = exp(-pow((r - inner * 1.1) / 0.08, 2.0));
                float cloudBand = saturate(ring * (verticalCore + verticalMist) * layerMask + bridge * 0.82);

                float dop = 1.0 + uMaterial._DopplerStrength * cos(theta - phiV - spin * 0.55);
                dop = clamp(dop, 0.55, 1.85);

                vec3 baseColor = mix(uMaterial._HotColor.rgb, uMaterial._WarmColor.rgb, smoothstep(0.1, 1.0, radial01));
                baseColor = mix(baseColor * uMaterial._CoolColor.rgb, baseColor, saturate(0.5 + 0.5 * dop));
                float lum = (0.30 + 1.15 * streak + 1.45 * hotRim) * cloudBand * reveal;
                vec3 rgb = baseColor * lum * dop * uMaterial._DiskBrightness;
                rgb += uMaterial._HotColor.rgb * hotRim * cloudBand * dop * uMaterial._HotRimBoost * reveal;
                rgb = rgb / (1.0 + max(rgb.r, max(rgb.g, rgb.b)) * uMaterial._ToneMapStrength);
                float alpha = saturate(lum * 0.72) * uMaterial._LayerAlpha;
                return vec4(rgb, alpha);
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 1) in vec3 pmInnormal; // @vertex Normal optional @default = vec4(0,1,0,0)
layout(location = 0) out vec2 pmVuv;
layout(location = 1) out vec3 pmVworldP;
void main() {
appdata pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.uv = pmInuv;
pmInput.normal = pmInnormal;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.pos;
pmVuv = pmOutput.uv;
pmVworldP = pmOutput.worldP;
}
