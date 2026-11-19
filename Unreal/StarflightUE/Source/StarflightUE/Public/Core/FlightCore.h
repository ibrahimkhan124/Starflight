#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

// Ported from Starflight's app-owned Swift maths. SI units, +Y up, forward -Z.
// No Apple or Unreal dependency: the adapter alone converts to Unreal centimetres.
namespace starflight {
constexpr float Pi=3.14159265358979323846f;
constexpr float Step=1.0f/120.0f;
inline float Clamp(float v,float lo,float hi) { return std::clamp(v,lo,hi); }
struct Vec3 {
    float x=0,y=0,z=0;
    Vec3 operator+(Vec3 b) const { return {x+b.x,y+b.y,z+b.z}; }
    Vec3 operator-(Vec3 b) const { return {x-b.x,y-b.y,z-b.z}; }
    Vec3 operator*(float s) const { return {x*s,y*s,z*s}; }
    float Length() const { return std::sqrt(x*x+y*y+z*z); }
};
struct Input { float pitch=0,roll=0,yaw=0,throttle=0;bool boost=false; };
struct Handling { float cruise=165,response=4.2f,maxPitch=0.62f,maxRoll=1.35f,yawAuthority=0.38f; };
struct State {
    Vec3 position{0,430,250},velocity{};
    float pitch=0,roll=0,heading=0,pitchRate=0,rudder=0;
    Vec3 Forward() const { return {std::sin(heading)*std::cos(pitch),std::sin(pitch),-std::cos(heading)*std::cos(pitch)}; }
};
inline void Advance(State& s,Input i,float dt,Handling h={}) {
    if (!std::isfinite(dt) || dt<=0 || dt>0.1f) return;
    auto axis=[](float v) { return std::isfinite(v) ? Clamp(v,-1,1):0; };
    i.pitch=axis(i.pitch);i.roll=axis(i.roll);i.yaw=axis(i.yaw);i.throttle=axis(i.throttle);
    const float neutral=std::atan2(std::sin(s.pitch),std::cos(s.pitch));
    const float target=std::abs(i.pitch)>0.04f ? i.pitch*h.maxPitch*1.6f:Clamp(-neutral*0.7f,-0.35f,0.35f);
    s.pitchRate+=(target-s.pitchRate)*(1-std::exp(-dt*7));s.pitch+=s.pitchRate*dt;
    s.roll=Clamp(s.roll,-h.maxRoll,h.maxRoll);
    s.roll+=(i.roll*h.maxRoll-s.roll)*(1-std::exp(-dt*h.response));
    const float rate=i.yaw*s.rudder<0 || std::abs(i.yaw)<0.01f ? 24:16;
    s.rudder+=(i.yaw-s.rudder)*(1-std::exp(-std::min(dt,0.1f)*rate));
    s.heading=std::fmod(s.heading+(s.rudder*h.yawAuthority+std::sin(s.roll)*0.72f)*dt,2*Pi);
    const float speed=h.cruise*1.45f*i.throttle*(i.boost && i.throttle>0 ? 1.3f:1);
    s.velocity=s.velocity+(s.Forward()*speed-s.velocity)*(1-std::exp(-dt*1.6f));
    s.position=s.position+s.velocity*dt;
}
struct Terrain {
    std::uint32_t seed=7319;
    static constexpr float Spacing=50;
    static constexpr float MinX=-2400,MaxX=2400,MinZ=-9000,MaxZ=1000;
    float Hash(std::int32_t x,std::int32_t z) const {
        std::uint32_t n=std::uint32_t(x)*374761393u+std::uint32_t(z)*668265263u+seed;
        n=(n^(n>>13))*1274126177u;
        return float((n^(n>>16))&0x00ffffffu)/float(0x00ffffffu);
    }
    float Noise(float x,float z) const {
        const auto ix=std::int32_t(std::floor(x)),iz=std::int32_t(std::floor(z));
        const float fx=x-std::floor(x),fz=z-std::floor(z),u=fx*fx*(3-2*fx),v=fz*fz*(3-2*fz);
        const float a=Hash(ix,iz)*(1-u)+Hash(ix+1,iz)*u,b=Hash(ix,iz+1)*(1-u)+Hash(ix+1,iz+1)*u;
        return a*(1-v)+b*v;
    }
    float Fractal(float x,float z) const { return Noise(x,z)*0.57f+Noise(x*2,z*2)*0.28f+Noise(x*4,z*4)*0.15f; }
    float Height(float x,float z) const {
        const float difficulty=Clamp(-z/9050,0,1),center=290*std::sin(-z*0.00056f)+115*std::sin(-z*0.00056f*2.2353f);
        const float ridge=1-std::exp(-std::pow(std::abs(x-center)/(650-difficulty*150),1.65f));
        const float floor=95+55*std::sin(z*0.00055f)+42*Fractal(x*0.003f,z*0.003f);
        const float saddle=std::pow(std::max(0.0f,std::sin(-z*0.0021f-0.8f)),4)*(120+difficulty*230)*0.7f;
        return floor+ridge*(480+Fractal(x*0.0018f,z*0.0018f)*680+difficulty*490)*0.68f+saddle;
    }
    bool Contains(Vec3 p) const { return p.x>=MinX && p.x<=MaxX && p.z>=MinZ && p.z<=MaxZ; }
    // Same triangles and diagonal as the procedural Unreal mesh (50 m prototype grid).
    float Surface(float x,float z) const {
        const float x0=std::floor(x/Spacing)*Spacing,z0=std::floor(z/Spacing)*Spacing;
        const float u=(x-x0)/Spacing,v=(z-z0)/Spacing;
        const float a=Height(x0,z0),b=Height(x0+Spacing,z0),c=Height(x0,z0+Spacing),d=Height(x0+Spacing,z0+Spacing);
        return u+v<=1 ? a+(b-a)*u+(c-a)*v:d+(c-d)*(1-u)+(b-d)*(1-v);
    }
};
// Explicit axis/handedness conversion: Unreal +X forward, +Y right, +Z up, centimetres.
inline Vec3 ToUnreal(Vec3 p) { return {-p.z*100,p.x*100,p.y*100}; }
inline Vec3 FromUnreal(Vec3 p) { return {p.y/100,p.z/100,-p.x/100}; }
}
