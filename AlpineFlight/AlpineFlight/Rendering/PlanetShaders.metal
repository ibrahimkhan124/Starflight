#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Original, bounded-cost shaders. Large landforms remain collision-aligned CPU
// geometry; only material detail, water normals and atmosphere vary per pixel.
namespace {
constexpr sampler sfRepeat(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
float sfHash(int3 p) {
    uint h = uint(p.x)*374761393u ^ uint(p.y)*668265263u ^ uint(p.z)*2246822519u;
    h = (h ^ (h>>13))*1274126177u;
    return float((h ^ (h>>16)) & 65535u)/65535.0;
}
float sfNoise(float3 p) {
    int3 i = int3(floor(p)); float3 f = fract(p); f = f*f*(3.0-2.0*f);
    float a = mix(sfHash(i),sfHash(i+int3(1,0,0)),f.x);
    float b = mix(sfHash(i+int3(0,1,0)),sfHash(i+int3(1,1,0)),f.x);
    float c = mix(sfHash(i+int3(0,0,1)),sfHash(i+int3(1,0,1)),f.x);
    float d = mix(sfHash(i+int3(0,1,1)),sfHash(i+int3(1,1,1)),f.x);
    return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
}
float sfFbm(float3 p,int count) {
    float result=0,weight=0.55,total=0;
    for(int i=0;i<count;i++) { result+=sfNoise(p)*weight;total+=weight;p=p*2.07+float3(11.3,7.1,3.7);weight*=0.47; }
    return result/max(total,0.001);
}
float3 sfSun() { return normalize(float3(800,1200,900)); }
float3 sfView(realitykit::surface_parameters p) {
    float4x4 m=p.uniforms().world_to_view();
    float3 t=m[3].xyz;
    float3 camera=-float3(dot(m[0].xyz,t),dot(m[1].xyz,t),dot(m[2].xyz,t));
    return normalize(camera-p.geometry().world_position());
}
float3 sfWorldNormal(realitykit::surface_parameters p) {
    return normalize((p.uniforms().model_to_world()*float4(p.geometry().normal(),0)).xyz);
}
float sfDistance(realitykit::surface_parameters p) {
    return length((p.uniforms().model_to_view()*float4(p.geometry().model_position(),1)).xyz);
}
float3 sfHorizon(int body) {
    switch(body) {
        case 1:return float3(.80,.57,.34); case 2:return float3(.65,.79,.88);
        case 3:return float3(.43,.52,.40); case 4:return float3(.055,.065,.12);
        case 6:return float3(.64,.43,.18); case 7:return float3(.60,.74,.83);
        case 8:return float3(.57,.35,.24); case 9:return float3(.68,.56,.39);
        default:return float3(.01,.012,.016);
    }
}
float sfDensity(int body) {
    switch(body) { case 1:return .00010;case 2:return .00013;case 3:return .00010;case 4:return .000045;
        case 6:return .00022;case 7:return .00009;case 8:return .00012;case 9:return .00014;default:return 0; }
}
float sfMie(float mu) {
    constexpr float g=.72;
    return (1-g*g)/(4*M_PI_F*pow(max(.05,1+g*g-2*g*mu),1.5));
}
float3 sfGround(int body,float3 pos,float3 n,float macro) {
    float slope=1-saturate(n.y),h=pos.y;
    switch(body) {
        case 1: { float strata=.04*sin(h*.045+macro*4); return mix(float3(.70,.46,.24),float3(.50,.27,.13),smoothstep(.23,.70,slope))+strata; }
        case 2:return mix(float3(.84,.91,.96),float3(.25,.48,.64),smoothstep(.24,.76,slope))*(.94+.1*macro);
        case 3:return mix(float3(.15,.27,.10),float3(.28,.30,.22),smoothstep(.22,.72,slope))*(.84+.3*macro);
        case 4:return float3(.055,.065,.095);
        case 5:return float3(.40,.39,.37)*(.81+.30*macro);
        case 6:return mix(float3(.20,.18,.13),float3(.34,.28,.18),macro);
        case 7: {
            float3 grass=mix(float3(.12,.26,.08),float3(.30,.37,.16),macro);
            float3 rock=mix(float3(.31,.33,.31),float3(.55,.56,.52),macro);
            float3 land=mix(grass,rock,smoothstep(.21,.62,slope));
            float snow=smoothstep(1500,2100,h+macro*160)*(1-smoothstep(.35,.85,slope));
            return mix(land,float3(.87,.91,.92),snow);
        }
        case 8:return mix(float3(.48,.21,.11),float3(.69,.36,.20),macro)*(.96+.035*sin(h*.07+macro*7));
        default:return float3(.73,.62,.45);
    }
}
}

[[visible]] void starflight_ground(realitykit::surface_parameters p) {
    auto s=p.surface(); float4 settings=p.uniforms().custom_parameter();
    int kind=int(settings.x+.5),body=int(settings.y+.5);
    float3 pos=p.geometry().world_position(),n=sfWorldNormal(p),v=sfView(p);
    float distance=sfDistance(p);
    // Shader LOD and mipmaps remove sub-pixel grain instead of changing terrain.
    float pixel=max(length(dfdx(pos)),length(dfdy(pos)));
    float detail=(1-smoothstep(.6,8.0,pixel))*(1-smoothstep(1000.0,5200.0,distance));
    if(settings.w>.5) detail*=.45;
    int octaves=settings.w>.5 || distance>5000 ? 2:3;
    float macro=sfFbm(pos*.003,octaves);
    half4 tex=p.textures().base_color().sample(sfRepeat,p.geometry().uv0());
    float3 color=float3(p.material_constants().base_color_tint())*float3(tex.rgb);
    if(settings.z>.5) color=sfGround(body,pos,n,macro)*(.93+.13*float(tex.r));
    if(body==1 && settings.z>1.5) {
        // Portals Canyon of Light study: world-anchored, warped bedding at two scales.
        // Native RealityKit lighting remains in command; no baked camera-facing bounce.
        float bed=pos.y*.08+sin(pos.x*.003+pos.z*.002)*2.4+macro*5;
        float aa=max(.02,fwidth(bed));
        float layer=smoothstep(-.7-aa,.8+aa,sin(bed));
        float fine=sin(bed*5.7)*(1-smoothstep(.15,1.0,fwidth(bed*5.7)));
        float wall=smoothstep(.08,.55,1-n.y);
        float3 rock=mix(float3(.54,.30,.15),float3(.65,.40,.23),layer);
        color=mix(float3(.73,.51,.29),rock,wall)*(.96+.035*fine);
    }
    color*=.92+.16*macro;
    float roughness=kind==1 ? .78:.94;
    if(kind==5) { // Dense cloud geometry: gentle forward-scattered fill.
        color*=.91+.17*macro;
        s.set_emissive_color(half3(color*(.06+.12*max(0.0,dot(v,sfSun())))));
        roughness=1;
    }
    half3 map=realitykit::unpack_normal(p.textures().normal().sample(sfRepeat,p.geometry().uv0()).rgb);
    s.set_normal(normalize(mix(float3(0,0,1),float3(map),detail*.55)));
    float mu=dot(v,sfSun());
    float rayleigh=.0596831*(1+mu*mu);
    float fog=1-exp(-distance*sfDensity(body));
    float3 scatter=sfHorizon(body)*(1+rayleigh*.3+min(.3,sfMie(mu)*.08));
    s.set_base_color(half3(mix(color,scatter,fog*.70)));
    s.set_emissive_color(half3(scatter*fog*.13+(kind==5 ? color*.07:float3(0))));
    s.set_roughness(half(roughness));s.set_metallic(0);s.set_specular(.28);
}

[[visible]] void starflight_water(realitykit::surface_parameters p) {
    auto s=p.surface();float3 pos=p.geometry().world_position();float t=p.uniforms().time();
    float distance=sfDistance(p),lod=1-smoothstep(1000.0,9000.0,distance);
    float2 wave=float2(sin(pos.x*.032+pos.z*.019+t*.75)+.45*sin(pos.z*.071-t*1.2),
                       cos(pos.z*.029-pos.x*.017+t*.57)+.4*cos(pos.x*.081+t));
    float3 n=normalize(float3(wave.x*.08*lod,1,wave.y*.08*lod)),v=sfView(p);
    s.set_normal(normalize(float3(wave*.075*lod,1)));
    float fresnel=.025+.975*pow(1-saturate(dot(n,v)),5.0);
    float3 reflection=reflect(-v,n);
    float3 sky=mix(float3(.58,.73,.83),float3(.10,.24,.43),smoothstep(.05,.8,reflection.y));
    float glint=pow(max(0.0,dot(reflection,sfSun())),340.0)*1.1;
    float3 blue=float3(p.material_constants().base_color_tint());
    s.set_base_color(half3(mix(blue,sky,fresnel*.7)));
    s.set_emissive_color(half3(sky*fresnel*.17+float3(1,.91,.72)*glint));
    s.set_roughness(.17);s.set_metallic(0);s.set_specular(.95);s.set_clearcoat(.5);s.set_clearcoat_roughness(.12);
}

[[visible]] void starflight_cloud(realitykit::surface_parameters p) {
    float4 settings=p.uniforms().custom_parameter();int body=int(settings.x+.5);
    bool orbital=settings.z>.5; float time=p.uniforms().time();
    float3 coordinate=orbital ? normalize(p.geometry().model_position())*9.0 : float3(p.geometry().world_position().xz*.0018,1);
    coordinate+=float3(time*.004,0,time*.002);
    float noise=sfFbm(coordinate,settings.y>.5 ? 2:3);
    float coverage=smoothstep(orbital ? .43:.28,orbital ? .67:.72,noise);
    // Venus has an optically thick cloud deck; its radar map should not look
    // like an exposed orange rocky planet from orbit.
    if(orbital && body==6) coverage=.93+.07*noise;
    if(!orbital) { float2 q=p.geometry().uv0()*2-1;coverage*=pow(saturate(1-dot(q,q)),.7); }
    float3 n=sfWorldNormal(p),v=sfView(p);
    float sun=orbital ? smoothstep(-.2,.4,dot(n,sfSun())) : .85;
    float silver=pow(saturate(1-coverage),2)*min(.6,sfMie(dot(v,sfSun()))*.12);
    float3 tint=float3(p.material_constants().base_color_tint());
    p.surface().set_emissive_color(half3(tint*(.35+.65*sun+silver)));
    p.surface().set_opacity(half(coverage*settings.w));
}

[[visible]] void starflight_atmosphere(realitykit::surface_parameters p) {
    int body=int(p.uniforms().custom_parameter().x+.5);
    float3 n=sfWorldNormal(p),v=sfView(p);
    float limb=pow(saturate(1-abs(dot(n,v))),2.6);
    float sun=smoothstep(-.22,.5,dot(n,sfSun()));
    float mu=dot(v,sfSun());float rayleigh=.0596831*(1+mu*mu);
    float phase=rayleigh*3+min(.75,sfMie(mu)*.14);
    float3 tint=sfHorizon(body);
    p.surface().set_emissive_color(half3(tint*(.65+phase)*sun));
    p.surface().set_opacity(half(limb*(.38+phase)*sun));
}

[[visible]] void starflight_globe(realitykit::surface_parameters p) {
    int body=int(p.uniforms().custom_parameter().x+.5);
    auto s=p.surface();half4 sample=p.textures().base_color().sample(sfRepeat,p.geometry().uv0());
    float3 rgb=float3(sample.rgb)*float3(p.material_constants().base_color_tint());
    float3 direction=normalize(p.geometry().model_position());
    float pixel=max(length(dfdx(direction)),length(dfdy(direction)));
    float fine=1-smoothstep(.001,.012,pixel);
    float grain=sfFbm(direction*75.0,2);
    bool water=body==7 && rgb.b>rgb.g*1.12 && rgb.b>rgb.r*1.5;
    if(water) { s.set_roughness(.16);s.set_specular(.9); }
    else { rgb*=.88+grain*.24*fine;s.set_roughness(.93);s.set_specular(.2); }
    s.set_base_color(half3(rgb));s.set_metallic(0);
    float bump=(grain-.5)*fine*.13;
    s.set_normal(normalize(float3(bump,-bump*.7,1)));
}

// Aether CPU TerrainSurface reflectance map -> RealityKit PBR adapter.
// Detail is app-owned; the library's direct-Metal renderer is not imported.
[[visible]] void starflight_aether_surface(realitykit::surface_parameters p) {
    float3 pos=p.geometry().world_position();
    float pixel=max(length(dfdx(pos)),length(dfdy(pos)));
    float fade=1-smoothstep(.5,9.0,pixel);
    float grain=sfFbm(pos*.19,2);
    float3 rgb=float3(p.textures().base_color().sample(sfRepeat,float2(p.geometry().uv0().x,1-p.geometry().uv0().y)).rgb);
    rgb*=mix(1.0,.88+.24*grain,fade);
    float e=.35;
    float dx=sfNoise((pos+float3(e,0,0))*.19)-sfNoise((pos-float3(e,0,0))*.19);
    float dz=sfNoise((pos+float3(0,0,e))*.19)-sfNoise((pos-float3(0,0,e))*.19);
    p.surface().set_base_color(half3(rgb));
    p.surface().set_normal(normalize(float3(-dx*fade,-dz*fade,1)));
    p.surface().set_roughness(half(.82+.12*grain));
    p.surface().set_metallic(0);p.surface().set_specular(.24);
}
