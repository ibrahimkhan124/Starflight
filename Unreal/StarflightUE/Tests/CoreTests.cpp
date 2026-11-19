#include "Core/FlightCore.h"
#include <cstdlib>
#include <iostream>
#include <limits>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static void Require(bool ok,const char* message) {
    if(!ok) { std::cerr<<"FAIL: "<<message<<'\n';std::exit(1); }
}
int main(int argc,char** argv) {
    using namespace starflight;
    State forward,backward;
    for(int i=0;i<1200;++i) {
        Advance(forward,{0,0,0,1,false},Step);
        Advance(backward,{0,0,0,-1,false},Step);
    }
    Require(forward.position.z<-1900 && backward.position.z>2000,"signed throttle moves in both directions");
    Require(std::abs(forward.velocity.Length()-165*1.45f)<0.01f,"speed settles to Swift X-wing preset");
    State right;
    for(int i=0;i<240;++i) Advance(right,{0,1,0,0.5f,false},Step);
    Require(right.heading>0 && right.position.x>0,"right bank turns east");
    Require(right.roll<=1.35f,"bank remains bounded");
    State loop;
    for(int i=0;i<1200;++i) Advance(loop,{1,0,0,0.5f,false},Step);
    Require(loop.pitch>2*Pi,"pitch can continue through a complete loop");
    const auto before=loop.position;
    Advance(loop,{},std::numeric_limits<float>::quiet_NaN());
    Require((loop.position-before).Length()==0,"invalid time cannot move flight state");
    const Vec3 input{12,345,-678},roundtrip=FromUnreal(ToUnreal(input));
    Require((input-roundtrip).Length()<0.001f,"Unreal conversion round trips in metres");
    Require(ToUnreal({0,0,-1}).x==100 && ToUnreal({0,1,0}).z==100,"forward/up axes map correctly");
    Terrain terrain,other;other.seed=11;
    Require(terrain.Hash(-3,7)==terrain.Hash(-3,7),"seeded noise is repeatable");
    Require(terrain.Height(900,-2400)!=other.Height(900,-2400),"seed changes terrain");
    for(int z=-8900;z<=900;z+=137) for(int x=-2300;x<=2300;x+=173) {
        const float x0=std::floor(float(x)/Terrain::Spacing)*Terrain::Spacing,z0=std::floor(float(z)/Terrain::Spacing)*Terrain::Spacing;
        const float u=(x-x0)/Terrain::Spacing,v=(z-z0)/Terrain::Spacing;
        const float a=terrain.Height(x0,z0),b=terrain.Height(x0+50,z0),c=terrain.Height(x0,z0+50),d=terrain.Height(x0+50,z0+50);
        const float sample=terrain.Surface(float(x),float(z));
        const float expected=u+v<=1 ? a*(1-u-v)+b*u+c*v:b*(1-v)+c*(1-u)+d*(u+v-1);
        Require(std::isfinite(sample) && std::abs(sample-expected)<0.001f,"collision height agrees with rendered triangle barycentrics");
    }
    Require(!terrain.Contains({2401,400,0}) && terrain.Contains({0,430,250}),"region limits are explicit");
    Require(argc==2,"Swift reference fixture supplied");
    std::ifstream fixture(argv[1]);Require(bool(fixture),"Swift reference fixture opens");
    std::string line;int samples=0;
    while(std::getline(fixture,line)) {
        std::stringstream row(line);std::vector<std::string> fields;std::string value;
        while(std::getline(row,value,',')) fields.push_back(value);
        if(fields.at(0)=="H") {
            Require(std::abs(terrain.Height(std::stof(fields.at(1)),std::stof(fields.at(2)))-std::stof(fields.at(3)))<0.002f,"Swift terrain recipe parity");
        } else {
            Input input;const auto& name=fields.at(1);
            if(name=="straight") input.throttle=1;
            else if(name=="reverse") input.throttle=-1;
            else if(name=="bank") { input.roll=1;input.throttle=0.5f; }
            else if(name=="pitch") { input.pitch=1;input.throttle=0.5f; }
            else if(name=="rudder") { input.yaw=1;input.throttle=0.5f; }
            else if(name=="mixed") { input.pitch=-0.2f;input.roll=0.4f;input.yaw=-0.6f;input.throttle=0.8f; }
            else Require(false,"known reference scenario");
            State result;for(int i=0;i<240;++i) Advance(result,input,Step);
            const float actual[]={result.position.x,result.position.y,result.position.z,result.velocity.x,result.velocity.y,result.velocity.z,result.pitch,result.roll,result.heading};
            for(int i=0;i<9;++i) Require(std::abs(actual[i]-std::stof(fields.at(i+2)))<0.003f,"Swift quaternion-based flight parity");
        }
        ++samples;
    }
    Require(samples==11,"all Swift reference scenarios checked");
    std::cout<<"PASS: 11 Swift-reference samples plus  flight directions, loops, bank bounds, time guards, axes, seeded terrain and triangle agreement\n";
}
