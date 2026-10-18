#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BackgroundColor; // @color @default = vec4(0.019999999552965164, 0.006000000052154064, 0.0, 0.18000000715255737)
    vec4 _Color; // @color @default = vec4(1.0, 0.550000011920929, 0.07999999821186066, 1.0)
    vec4 _CoreColor; // @color @default = vec4(1.0, 0.8799999952316284, 0.3499999940395355, 1.0)
    vec4 _Time;
    float _Alpha; // @default = 1.0
    float _Aspect; // @default = 1.0
    float _CornerRadius; // @default = 0.07500000298023224
    float _FrameThickness; // @default = 0.009999999776482582
    float _GlowSize; // @default = 0.04500000178813934
    float _OrbIntensity; // @default = 2.5
    float _OrbSize; // @default = 0.052000001072883606
    float _OrbSpeed; // @default = 0.699999988079071
    float _PulseSpeed; // @default = 1.0
    float _State; // @default = 1.0
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
                vec4 color ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv ;
                vec4 color ;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            float RoundedBoxDistance(vec2 uv, vec2 halfSize, float radius)
            {
                vec2 p = abs(uv - 0.5) - halfSize + radius;
                return length(max(p, 0.0)) + min(max(p.x, p.y), 0.0) - radius;
            }

            float PerimeterLength(float aspect)
            {
                return 2.0 * (max(aspect, 0.001) + 1.0);
            }

            vec2 PerimeterPoint(float distanceAlong, float aspect)
            {
                float a = max(aspect, 0.001);
                float p = fract(distanceAlong / PerimeterLength(a)) * PerimeterLength(a);
                if (p < a)
                    return vec2(p / a, 0.0);
                p -= a;
                if (p < 1.0)
                    return vec2(1.0, p);
                p -= 1.0;
                if (p < a)
                    return vec2(1.0 - p / a, 1.0);
                p -= a;
                return vec2(0.0, 1.0 - p);
            }

            vec2 PerimeterTangent(float distanceAlong, float aspect)
            {
                float a = max(aspect, 0.001);
                float p = fract(distanceAlong / PerimeterLength(a)) * PerimeterLength(a);
                if (p < a)
                    return vec2(1.0, 0.0);
                p -= a;
                if (p < 1.0)
                    return vec2(0.0, 1.0);
                p -= 1.0;
                if (p < a)
                    return vec2(-1.0, 0.0);
                p -= a;
                return vec2(0.0, -1.0);
            }

            vec2 PerimeterNormal(vec2 p)
            {
                vec2 fromCenter = p - 0.5;
                if (abs(fromCenter.x) > abs(fromCenter.y))
                    return vec2(sign(fromCenter.x), 0.0);
                return vec2(0.0, sign(fromCenter.y));
            }

            float EnergyDroplet(vec2 uv, vec2 pos, vec2 tangent, vec2 normal, vec2 aspectScale, float size)
            {
                vec2 d = (uv - pos) * aspectScale;
                vec2 t = normalize(tangent * aspectScale);
                vec2 n = normalize(normal * aspectScale);
                float along = dot(d, t);
                float outward = dot(d, n);

                float head = exp(-((along * along) / (size * size * 0.50) + (outward * outward) / (size * size * 0.34)));
                float tailMask = saturate((-along) / (size * 4.0));
                float tailWidth = mix(size * 0.20, size * 0.62, 1.0 - tailMask);
                float tail = exp(-(outward * outward) / max(tailWidth * tailWidth, 0.00001)) * exp(along / max(size * 2.8, 0.00001)) * step(along, 0.0);
                float outerBulge = exp(-((along * along) / (size * size * 0.74) + ((outward - size * 0.38) * (outward - size * 0.38)) / (size * size * 0.30)));

                return head * 1.35 + tail * 0.75 + outerBulge * 0.52;
            }

            vec4 frag(v2f i) 
            {
                vec2 uv = saturate(i.uv);
                float radius = uMaterial._CornerRadius;
                float dist = RoundedBoxDistance(uv, vec2(0.5, 0.5), radius);
                float inside = 1.0 - smoothstep(0.002, 0.010, dist);
                float innerDist = RoundedBoxDistance(uv, vec2(0.5 - uMaterial._FrameThickness, 0.5 - uMaterial._FrameThickness), max(0.0, radius - uMaterial._FrameThickness));
                float innerInside = 1.0 - smoothstep(0.002, 0.010, innerDist);

                float frame = saturate(inside - innerInside);
                float outsideGlow = 1.0 - smoothstep(0.0, uMaterial._GlowSize, abs(dist));
                outsideGlow *= inside;

                float aspect = max(uMaterial._Aspect, 0.001);
                float perimeter = PerimeterLength(aspect);
                float orbPhase0 = uMaterial._Time.y * uMaterial._OrbSpeed;
                float orbPhase1 = orbPhase0 + perimeter * 0.5;
                vec2 orbPos0 = PerimeterPoint(orbPhase0, aspect);
                vec2 orbPos1 = PerimeterPoint(orbPhase1, aspect);
                vec2 tangent0 = PerimeterTangent(orbPhase0, aspect);
                vec2 tangent1 = PerimeterTangent(orbPhase1, aspect);
                vec2 normal0 = PerimeterNormal(orbPos0);
                vec2 normal1 = PerimeterNormal(orbPos1);
                vec2 aspectScale = vec2(aspect, 1.0);
                float orb0 = EnergyDroplet(uv, orbPos0, tangent0, normal0, aspectScale, uMaterial._OrbSize);
                float orb1 = EnergyDroplet(uv, orbPos1, tangent1, normal1, aspectScale, uMaterial._OrbSize * 0.78);
                float orbFrameMask = saturate(frame + outsideGlow * 0.85);
                float orb = (orb0 + orb1 * 0.55) * orbFrameMask * uMaterial._OrbIntensity;

                float scan = 0.55 + 0.45 * sin((uv.x + uv.y) * 26.0 - uMaterial._Time.y * uMaterial._PulseSpeed * 6.2831853);
                float energy = saturate(frame * (0.85 + scan * 0.25) + outsideGlow * 0.36 + orb);

                vec4 col = uMaterial._BackgroundColor * innerInside;
                col.rgb += uMaterial._Color.rgb * energy * uMaterial._State;
                col.rgb += uMaterial._CoreColor.rgb * saturate(orb) * uMaterial._State;
                col.a = saturate(uMaterial._BackgroundColor.a * innerInside + energy * uMaterial._Color.a) * uMaterial._Alpha * i.color.a;
                col.rgb *= i.color.rgb;
                return col;
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 2) in vec4 pmIncolor; // @vertex Color optional @default = vec4(1.0)
layout(location = 1) out vec2 pmVuv;
layout(location = 0) out vec4 pmVcolor;
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
