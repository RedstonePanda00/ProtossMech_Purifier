#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } camera;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _Accent; // @default = vec4(0.72, 0.78, 0.40, 1.0)
    vec4 _Viewport; // @default = vec4(1440.0, 1040.0, 0.0, 0.0)
    vec4 _Interaction; // @default = vec4(0.0, 1.0, 0.0, 0.0)
} material;
layout(set = 2, binding = 1) uniform sampler2D _MainTex;
layout(set = 2, binding = 2) uniform sampler2D _PreviousTex;
layout(location = 1) in vec2 texcoord;
layout(location = 0) out vec4 outColor;
float hash(vec2 p) { vec3 q=fract(vec3(p.xyx)*0.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
float dots(vec2 p, float pitch, float radius) {
    vec2 q=mod(p,pitch)-pitch*.5;
    return 1.0-smoothstep(radius,radius+0.65,length(q));
}
float signalPeak(float x, float centre, float width) {
    return pow(max(0.0,1.0-abs(x-centre)/width),1.35);
}
vec3 stage(vec2 uv, float time) {
    float aspect=material._Viewport.x/max(1.0,material._Viewport.y);
    vec2 q=(uv-.5)*vec2(aspect,1.0);
    float halo=exp(-dot(q*vec2(1.3,2),q*vec2(1.3,2))*3.0);
    vec3 air=vec3(.009,.013,.018)+vec3(.15,.19,.23)*halo;
    float down=.18-q.y;
    vec3 color=air;
    // Analytic floor intersection. No per-pixel raymarch or volumetric integration loop.
    if(down>.045) {
        float t=1.45/down;
        vec2 p=vec2(q.x*t,1.25*t-3.6);
        float broad=noise(p*2.6), grain=noise(p*34.0);
        float pool=exp(-dot(p-vec2(0,1.5),p-vec2(0,1.5))*.10);
        float ridges=abs(broad-.5);
        vec3 stone=mix(vec3(.045,.05,.055),vec3(.16,.155,.145),broad)*(.60+grain*.55);
        float contact=1.0-.43*exp(-p.x*p.x*.45-(p.y-1.6)*(p.y-1.6)*1.4);
        vec3 floorColor=stone*(.20+pool*(1.6-ridges)) * contact + material._Accent.rgb*.018*pool;
        color=mix(floorColor,air,max(1.0-exp(-t*.045),smoothstep(16.0,34.0,t)));
    }
    // Visible drifting sheets behind the weapon. Two advected scales give billows
    // and wisps without restoring the costly volumetric raymarch.
    vec2 drift=vec2(time*.045,-time*.017);
    float billow=noise(uv*vec2(5.0,7.0)-drift);
    float wisp=noise(uv*vec2(12.0,16.0)+vec2(billow*.7,-billow*.4)-drift*1.6);
    float density=smoothstep(.32,.70,billow*.68+wisp*.32);
    float band=exp(-pow((uv.y-.48)*4.0,2.0));
    float mist=density*band*(.65+.35*halo);
    color=mix(color,vec3(.38,.43,.47),mist*.72);
    color*=.25+.75*(1.0-smoothstep(.25,1.0,length((uv-.5)*vec2(1.35,1.1))));
    return color+(hash(gl_FragCoord.xy)-.5)*.003;
}
void main() {
    vec2 uv=texcoord, size=max(material._Viewport.xy,vec2(1)), p=uv*size;
    float mode=material._Viewport.w, time=material._Viewport.z;
    float state=material._Interaction.x, alpha=material._Interaction.y;
    float hover=material._Interaction.z;
    vec3 accent=material._Accent.rgb;
    if(mode>6.5) {
        // Slot hover: sparse radial dot halo and a small cross-light, independent of selection.
        vec2 d=p-size*.5;
        float field=exp(-dot(d/size,d/size)*10.0);
        float grid=dots(p,5.0,.65)*field*(.55+.20*sin(time*3.2+length(d)*.10));
        float cross=exp(-abs(d.x)*2.2)*exp(-abs(d.y)*.10)+exp(-abs(d.y)*2.2)*exp(-abs(d.x)*.10);
        outColor=vec4(mix(accent,vec3(1),.45),alpha*hover*(grid*.50+cross*.48)); return;
    }
    if(mode>5.5) {
        // Stable axis and peak locations, with aperiodic local stretching, contraction
        // and fine point displacement. This is neither a scrolling waveform nor a
        // common sinusoidal scale applied to the entire cloud.
        float x=uv.x, y=(uv.y-.49)*2.0;
        float upperPulse=noise(vec2(time*4.5,17.4));
        float lowerPulse=noise(vec2(time*3.8,63.7));
        float needlePulse=noise(vec2(time*6.2,39.8));
        float upper=.022+.10*signalPeak(x,.61,.28);
        upper+= (.20+.47*upperPulse)*signalPeak(x,.79+.009*noise(vec2(time*2.2,4.1)),.12-.065*upperPulse);
        upper+= (.12+.55*needlePulse)*signalPeak(x,.855,.047-.025*needlePulse);
        float lower=.022+.15*signalPeak(x,.57,.24);
        lower+= (.30+.58*lowerPulse)*signalPeak(x,.72+.010*noise(vec2(time*2.5,24.6)),.15-.085*lowerPulse);
        lower+= .14*signalPeak(x,.83,.10);
        float ripple=(noise(vec2(x*48.0,time*6.0))-.5)*.055;
        float height=max(.008,(y>=0.0?upper:lower)+ripple);
        float ratio=abs(y)/height;
        float silhouette=1.0-smoothstep(.82,1.08,ratio);
        float ridge=exp(-pow((ratio-.78)*8.0,2.0))*.28;
        float fade=smoothstep(.05,.30,x)*(1.0-smoothstep(.94,1.02,x));
        vec2 displacement=vec2(noise(vec2(p.y*.045,time*3.1)),noise(vec2(p.x*.04,time*4.2)))-.5;
        vec2 pointSpace=p+displacement*vec2(2.4,3.2);
        vec2 cell=floor(pointSpace/1.15), local=fract(pointSpace/1.15);
        float seed=hash(cell);
        vec2 centre=vec2(.16+.68*seed,.16+.68*hash(cell+19.7));
        float point=1.0-smoothstep(.12,.43,length(local-centre));
        vec2 fineSpace=pointSpace/.87+vec2(.31,.73);
        vec2 fineCell=floor(fineSpace);
        vec2 fineCentre=vec2(.15+.7*hash(fineCell+5.2),.15+.7*hash(fineCell+42.8));
        float finePoint=1.0-smoothstep(.10,.39,length(fract(fineSpace)-fineCentre));
        float shimmer=.82+.18*sin(time*9.0+seed*6.28318);
        float cloud=(point*.76+finePoint*.43)*(.55+seed*.45)*shimmer*(silhouette*.82+ridge);
        // A shallow drifting strand connects the peaks to the sparse left-hand tail.
        float strandY=.014*(noise(vec2(x*19.0,time*4.0))-.5);
        float strand=exp(-abs(y-strandY)*size.y*.52)*(.25+.40*signalPeak(x,.76,.6));
        float halo=point*step(.82,seed)*exp(-abs(y)*9.0)*.18;
        float column=floor(p.x/1.35);
        float streak=step(.982,hash(vec2(column,7.1)))*pow(.5+.5*sin(time*2.2+column),3.0);
        streak*=step(y,-.04)*exp(y*3.0)*.30;
        outColor=vec4(mix(vec3(.79,.90,.94),accent,.025),alpha*fade*(cloud+strand+halo+streak)); return;
    }
    if(mode>4.5) {
        float value=clamp(state,0,1), baseline=clamp(hover,0,1);
        float common=min(value,baseline), extent=max(value,baseline);
        float filled=1.0-step(extent,uv.x);
        // 1.3px white bars and 0.9px gaps, independent of theme colour.
        float stripe=1.0-smoothstep(1.20,1.48,mod(p.x,2.2));
        vec3 ink=uv.x<common?vec3(.96):value>=baseline?vec3(.47,.78,.24):vec3(.94,.36,.33);
        outColor=vec4(ink,alpha*filled*stripe); return;
    }
    if(mode>3.5) {
        vec4 weapon=texture(_MainTex,vec2(uv.x,1.0-uv.y));
        if(state>=.999) { outColor=vec4(weapon.rgb,weapon.a*alpha); return; }
        bool replacement=material._Interaction.w>.5;
        vec4 previous=vec4(0);
        if(replacement) {
            previous=texture(_PreviousTex,vec2(uv.x,1.0-uv.y));
            vec4 delta=abs(vec4(weapon.rgb*weapon.a,weapon.a)-vec4(previous.rgb*previous.a,previous.a));
            // Compare the actual composited pixels, not a rectangular slot mask: the
            // receiver and overlapping unchanged parts stay fully opaque throughout.
            if(max(max(delta.r,delta.g),max(delta.b,delta.a))<.006) {
                outColor=vec4(weapon.rgb,weapon.a*alpha); return;
            }
        }
        float seed=hash(floor(p/5.0));
        float arrival=.08+seed*.50+uv.x*.10;
        float solid=smoothstep(arrival,arrival+.18,state);
        float dotMask=dots(p,4.0,.65+state*.40);
        float lattice=(1.0-smoothstep(.35,.85,min(mod(p.x,8.0),mod(p.y,8.0))))*.18;
        float particle=step(seed*.20,state)*max(dotMask,lattice)*(1.0-solid);
        vec3 ink=mix(mix(accent,vec3(.95),.65),weapon.rgb,solid);
        float newAlpha=weapon.a*clamp(solid+particle,0,1);
        float oldAlpha=previous.a*(1.0-smoothstep(0.0,.48,state));
        float combinedAlpha=newAlpha+oldAlpha*(1.0-newAlpha);
        vec3 premultiplied=ink*newAlpha+previous.rgb*oldAlpha*(1.0-newAlpha);
        outColor=vec4(premultiplied/max(combinedAlpha,.00001),combinedAlpha*alpha); return;
    }
    if(mode>2.5) {
        vec4 icon=texture(_MainTex,vec2(uv.x,1.0-uv.y));
        float detail=dot(icon.rgb,vec3(.2126,.7152,.0722));
        vec3 ink=mix(accent,vec3(1),.32+detail*.5);
        outColor=vec4(ink,icon.a*alpha); return;
    }
    if(mode<.5) {
        outColor=vec4(stage(uv,time),alpha*smoothstep(-.18,.02,state-uv.y)); return;
    }
    float edge=min(min(p.x,size.x-p.x),min(p.y,size.y-p.y));
    if(mode>1.5) {
        outColor=vec4(mix(vec3(.55),accent,.25),alpha*(1.0-smoothstep(.65,1.35,edge))*.65); return;
    }
    float selected=step(.9,state), enabled=step(0.0,state);
    float corner=min(p.x+size.y-p.y,size.x-p.x+p.y);
    float shape=smoothstep(5.0,6.0,corner);
    float frame=max(1.0-smoothstep(.65,1.35,edge),(1.0-smoothstep(.65,1.35,abs(corner-6.0)))*shape);
    float innerEdge=min(min(p.x-3.0,size.x-3.0-p.x),min(p.y-3.0,size.y-3.0-p.y));
    float inner=(1.0-smoothstep(.3,.85,abs(innerEdge)))*step(3.0,edge);
    // Distance along the perimeter grows counterclockwise in bottom-origin shader space.
    float along=p.x;
    if(size.x-p.x<=edge+.01) along=size.x+p.y;
    else if(size.y-p.y<=edge+.01) along=size.x+size.y+(size.x-p.x);
    else if(p.x<=edge+.01) along=2.0*size.x+size.y+(size.y-p.y);
    // Fixed dot centres. A few short, stationary segments pulse with local phase
    // offsets; there is no dot translation or highlight travelling around the frame.
    float dotIndex=floor(along/3.5);
    float dotDistance=abs(mod(along,3.5)-1.75);
    float segment=floor(dotIndex/7.0);
    float localIndex=mod(dotIndex,7.0);
    float localPhase=hash(vec2(segment,13.7))*6.28318;
    float localPulse=.5+.5*sin(time*2.5+localPhase-localIndex*.25);
    float chosen=step(.56,hash(vec2(dotIndex,41.3)));
    float radius=mix(.62,.46+localPulse*.90,chosen*hover);
    float dotted=1.0-smoothstep(radius,radius+.42,length(vec2(dotDistance,edge-.85)));
    float dotBrightness=mix(.48,.22+localPulse*.95,chosen*hover);
    float breath=.72+.28*sin(time*2.6);
    float bottom=pow(1.0-uv.y,2.0);
    float grid=dots(p,4.2,.65)*(.12+bottom*.75)*(selected*.72+hover*.32);
    float vertical=(1.0-smoothstep(.35,.9,mod(p.x,2.6)))*hover*.055;
    float sweep=exp(-pow((uv.x-.18)*4.0,2.0))*hover*(.07+.03*sin(time*2.5));
    vec3 fill=vec3(.018,.023,.023)+accent*(grid+vertical+sweep+selected*.035);
    vec3 border=mix(vec3(.52,.55,.52),accent,selected*.6+hover*.35);
    float borderStrength=.55+selected*.28+hover*.35;
    fill=mix(fill,border,frame*borderStrength);
    fill+=mix(accent,vec3(1),.6)*dotted*(selected*.5*breath+hover*dotBrightness);
    fill+=accent*inner*.25*(selected+hover);
    float opacity=mix(.67,.90,max(selected,hover))*alpha*shape;
    outColor=vec4(fill*mix(.42,1.0,enabled),opacity);
}
