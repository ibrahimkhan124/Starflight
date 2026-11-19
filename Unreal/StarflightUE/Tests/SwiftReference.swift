// Migration reference extracted from FlightPhysics.advanceSpace/FlightState.orientation
// and TerrainGenerator's alpine height/noise recipe. Run on the existing Mac toolchain.
import Foundation
import simd
let pi=Float.pi,dt:Float=1/120
func clamp(_ x:Float,_ a:Float,_ b:Float)->Float { min(max(x,a),b) }
func hash(_ x:Int32,_ z:Int32)->Float {
    var n=UInt32(bitPattern:x) &* 374761393 &+ UInt32(bitPattern:z) &* 668265263 &+ 7319
    n=(n ^ (n >> 13)) &* 1274126177
    return Float((n ^ (n >> 16)) & 0x00ffffff)/Float(0x00ffffff)
}
func noise(_ x:Float,_ z:Float)->Float {
    let ix=Int32(floor(x)),iz=Int32(floor(z)),fx=x-floor(x),fz=z-floor(z)
    let u=fx*fx*(3-2*fx),v=fz*fz*(3-2*fz)
    let a=hash(ix,iz)*(1-u)+hash(ix+1,iz)*u,b=hash(ix,iz+1)*(1-u)+hash(ix+1,iz+1)*u
    return a*(1-v)+b*v
}
func fractal(_ x:Float,_ z:Float)->Float { noise(x,z)*0.57+noise(x*2,z*2)*0.28+noise(x*4,z*4)*0.15 }
func height(_ x:Float,_ z:Float)->Float {
    let difficulty=clamp(-z/9050,0,1),center:Float=290*sin(-z*0.00056)+115*sin(-z*0.00056*2.2353)
    let ridge=1-exp(-pow(abs(x-center)/(650-difficulty*150),1.65))
    let floor:Float=95+55*sin(z*0.00055)+42*fractal(x*0.003,z*0.003)
    let saddle=pow(max(0,sin(-z*0.0021-0.8)),4)*(120+difficulty*230)*0.7
    return floor+ridge*(480+fractal(x*0.0018,z*0.0018)*680+difficulty*490)*0.68+saddle
}
func values(_ row:[Float])->String { row.map { String(format:"%.9g",Double($0)) }.joined(separator:",") }
for (x,z):(Float,Float) in [(0,250),(-900,-2400),(1500,-8400),(0,-9000),(-2400,1000)] {
    print("H,"+values([x,z,height(x,z)]))
}
for (name,axes):(String,SIMD4<Float>) in [("straight",[0,0,0,1]),("reverse",[0,0,0,-1]),("bank",[0,1,0,0.5]),("pitch",[1,0,0,0.5]),("rudder",[0,0,1,0.5]),("mixed",[-0.2,0.4,-0.6,0.8])] {
    var position=SIMD3<Float>(0,430,250),velocity=SIMD3<Float>.zero
    var pitch:Float=0,roll:Float=0,heading:Float=0,pitchRate:Float=0,rudder:Float=0
    for _ in 0..<240 {
        let neutral=atan2(sin(pitch),cos(pitch))
        let target:Float=abs(axes.x)>0.04 ? axes.x*0.62*1.6:clamp(-neutral*0.7,-0.35,0.35)
        pitchRate+=(target-pitchRate)*(1-exp(-dt*7));pitch+=pitchRate*dt
        roll=clamp(roll,-1.35,1.35);roll+=(axes.y*1.35-roll)*(1-exp(-dt*4.2))
        let rate:Float=axes.z*rudder<0 || abs(axes.z)<0.01 ? 24:16
        rudder+=(axes.z-rudder)*(1-exp(-min(dt,0.1)*rate))
        heading+=(rudder*0.38+sin(roll)*0.72)*dt;heading.formTruncatingRemainder(dividingBy:2*pi)
        let orientation=simd_quatf(angle:-heading,axis:[0,1,0])*simd_quatf(angle:pitch,axis:[1,0,0])*simd_quatf(angle:-roll,axis:[0,0,1])
        let desired=orientation.act([0,0,-1])*(165*1.45*axes.w)
        velocity+=(desired-velocity)*(1-exp(-dt*1.6));position+=velocity*dt
    }
    print("F,"+name+","+values([position.x,position.y,position.z,velocity.x,velocity.y,velocity.z,pitch,roll,heading]))
}
