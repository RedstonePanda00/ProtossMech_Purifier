#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _LocalCamera; // @default = vec4(0.0, 10.0, 0.0, 1.0)
    vec4 _LocalView; // @default = vec4(0.0, -1.0, 0.0, 0.0)
    vec4 _Life; // @default = vec4(0.0, 0.0, 1.0, 0.0)
    vec4 _Sweep; // @default = vec4(-1.0, 0.0, 1.0, 0.0)
    float _Phase; // @default = 0.0
    float _Steps; // @default = 48.0
} uMaterial;
layout(location = 0) in vec3 volumePosition;
layout(location = 0) out vec4 outColor;

float hash3(vec3 p)
{
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p)
{
    vec3 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(
        mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x),
            mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
        mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x),
            mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z);
}
vec2 intersectVolume(vec3 origin, vec3 direction)
{
    vec3 safeDir = mix(vec3(1e-5), direction, greaterThan(abs(direction), vec3(1e-5)));
    vec3 a = (vec3(-0.5,0.0,-0.5)-origin)/safeDir;
    vec3 b = (vec3( 0.5,1.0, 0.5)-origin)/safeDir;
    vec3 nearT = min(a,b), farT = max(a,b);
    return vec2(max(max(nearT.x,nearT.y),nearT.z), min(min(farT.x,farT.y),farT.z));
}
float densityAt(vec3 p, out float temperature)
{
    float h = max(p.y,0.0);
    float lengthAlong = length(push.modelMatrix[0].xyz);
    float time = uMaterial._Sweep.x >= 0.0 ? uMaterial._Sweep.x : uMaterial._Phase;
    // Lean real volume into a world-space breeze so tongues remain readable from the game's overhead camera.
    vec3 breeze = vec3(-0.25,0.0,1.0);
    float axisX = p.x*lengthAlong-dot(normalize(push.modelMatrix[0].xyz),breeze)*h;
    float crossLean = dot(normalize(push.modelMatrix[2].xyz),breeze)*h/3.0;
    float x = axisX + uMaterial._Sweep.w;
    // Fixed local metres and short-lived time keep the tongues anchored as the ignition front advances.
    float curledX = x + sin(h*6.0-time*3.3+x*0.8)*h*0.28;
    float crest = 0.5+0.5*sin(curledX*5.7+sin(x*2.3-time*3.2)+time*7.8);
    float tip = 0.23+0.67*pow(crest,1.4);
    float profileHeight = h/tip;
    float bend = sin(x*3.2-h*4.8+time*4.6)*h*0.10
        + sin(x*1.7+h*7.0-time*3.4)*h*0.045;
    float sideways = p.z-crossLean-bend;
    float width = mix(0.065,0.009,clamp(profileHeight,0.0,1.0));
    float radial = abs(sideways)/width;
    float crossSection = 1.0-smoothstep(0.15,1.0,radial);
    float axisLength = lengthAlong*uMaterial._Life.z;
    float ends = 1.0-smoothstep(0.1,0.45,abs(axisX)-axisLength*0.5);
    float turbulence = noise3(vec3(curledX*2.8,h*5.0-time*3.0,sideways*7.0));
    float tongues = 1.0-smoothstep(0.55,1.0,profileHeight);
    float density = crossSection*ends*tongues*mix(0.42,0.9,turbulence);
    float baseFlame = (1.0-smoothstep(0.015,0.065,h))
        * (1.0-smoothstep(0.025,0.05,abs(p.z))) * ends;
    density = max(density,baseFlame*0.45);
    temperature = clamp(1.0-profileHeight*0.8-radial*0.35,0.0,1.0);
    float along = clamp(axisX/max(axisLength,0.001)+0.5,0.0,1.0);
    float age = mix(uMaterial._Life.x,uMaterial._Life.y,along);
    if (uMaterial._Sweep.x >= 0.0) {
        float frontDistance = (uMaterial._Sweep.z-along)*max(axisLength,0.01);
        density *= smoothstep(-0.02,0.12,frontDistance);
        age = (uMaterial._Sweep.x-along*uMaterial._Sweep.y)/3.0;
    }
    return density*(1.0-smoothstep(0.70,1.0,age));
}
void main()
{
    vec3 direction, origin;
    if (uMaterial._LocalCamera.w > 0.5) {
        direction = normalize(uMaterial._LocalView.xyz);
        origin = volumePosition-direction*3.0;
    } else {
        origin = uMaterial._LocalCamera.xyz;
        direction = normalize(volumePosition-origin);
    }
    vec2 bounds = intersectVolume(origin,direction);
    bounds.x = max(bounds.x,0.0);
    if (bounds.y <= bounds.x) discard;
    int steps = clamp(int(uMaterial._Steps),16,48);
    float stepSize = (bounds.y-bounds.x)/float(steps);
    float worldStep = length(mat3(push.modelMatrix)*direction)*stepSize;
    vec3 radiance = vec3(0.0);
    float transmittance = 1.0;
    // Midpoint integration over the entire box depth; alpha derives from optical thickness.
    for (int i=0; i<48; i++) {
        if (i >= steps || transmittance < 0.015) break;
        vec3 point = origin+direction*(bounds.x+(float(i)+0.5)*stepSize);
        float temperature;
        float density = densityAt(point,temperature);
        if (density < 0.008) continue;
        float opacity = 1.0-exp(-density*1.8*worldStep);
        vec3 emission = mix(vec3(1.5,0.12,0.005),vec3(2.4,1.2,0.06),smoothstep(0.15,0.8,temperature));
        emission = mix(emission,vec3(3.1,2.7,0.7),smoothstep(0.58,0.95,temperature));
        radiance += transmittance*opacity*emission;
        transmittance *= 1.0-opacity;
    }
    float alpha = 1.0-transmittance;
    if (alpha < 0.003) discard;
    outColor = vec4(radiance,alpha);
}
