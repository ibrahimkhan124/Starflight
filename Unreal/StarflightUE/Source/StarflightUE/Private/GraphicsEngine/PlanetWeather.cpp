#include "PlanetWeather.h"
#include "Renderer.hpp"
#include "StarflightPrototype.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInterface.h"
#include "ProceduralMeshComponent.h"

namespace {
constexpr float FieldRadius = 4200;
constexpr int32 MaxBoulders = 12;
constexpr float RockPeriod = 20.f;
constexpr float RockLife = 16.f;
}

AStarflightWeather::AStarflightWeather() : Planet(EStarflightWorld::Hoth) {
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.TickInterval = 1.f / 30.f;
    Precipitation = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("WeatherParticles"));
    SetRootComponent(Precipitation);
    Precipitation->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Precipitation->SetCastShadow(false);
    Rocks = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("FallingBoulders"));
    Rocks->SetupAttachment(Precipitation);
    Rocks->SetMobility(EComponentMobility::Movable);
    Rocks->SetCollisionEnabled(ECollisionEnabled::NoCollision);
}

void AStarflightWeather::Configure(AStarflightRegion& Ground, EStarflightWorld World, UExponentialHeightFogComponent& Haze) {
    Region = &Ground;
    Planet = World;
    Fog = &Haze;
    Random.Initialize(72931 + static_cast<int32>(Planet));
    Precipitation->SetMaterial(0,ScenicMaterial(TEXT("M_Weather")));
    if (Planet == EStarflightWorld::Tatooine || Planet == EStarflightWorld::Hoth) {
        const bool Snow = Planet == EStarflightWorld::Hoth;
        Rocks->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,Snow ?
            TEXT("/Game/Starflight/Scenery/SM_GlacierRock.SM_GlacierRock") :
            TEXT("/Game/Starflight/Scenery/SM_SandstoneMesa.SM_SandstoneMesa")));
        Rocks->SetMaterial(0,ScenicMaterial(Snow ? TEXT("M_Ice") : TEXT("M_Sandstone")));
    }
#if PLATFORM_IOS
    constexpr int32 Count = 148;
#else
    constexpr int32 Count = 340;
#endif
    Particles.Reserve(Count);
    Colors.SetNumUninitialized(Count*4);
    Vertices.SetNumUninitialized(Count*4);
    Indices.Reserve(Count*6);
    for (int32 Index=0; Index<Count; ++Index) {
        Particles.Add({
            FVector(Random.FRandRange(-FieldRadius,FieldRadius),Random.FRandRange(-FieldRadius,FieldRadius),
                    Random.FRandRange(-FieldRadius,FieldRadius)),
            Random.FRandRange(0.55,1.4),
            Random.FRandRange(0.30,0.93)
        });
        const int32 Base = Index*4;
        Indices.Append({Base,Base+1,Base+2,Base+2,Base+3,Base});
    }
}

void AStarflightWeather::Tick(float DeltaSeconds) {
    Super::Tick(DeltaSeconds);
    auto* Ship = Cast<AStarflightPawn>(UGameplayStatics::GetPlayerPawn(this,0));
    if (!Ship || !Region || !Fog) return;
    const float Delta = FMath::Clamp(DeltaSeconds,0.f,0.1f);
    Elapsed += Delta;
    const float Gust = 0.48f + FMath::Sin(Elapsed*0.23f+0.9f)*0.27f + FMath::Sin(Elapsed*0.61f)*0.13f;
    UpdateWeather(*Ship,Delta,Gust);
    UpdateRocks(*Ship,Delta);
}

void AStarflightWeather::UpdateWeather(const AStarflightPawn& Ship, float Delta, float Gust) {
    const bool Dust = Planet == EStarflightWorld::Tatooine;
    const bool Snow = Planet == EStarflightWorld::Hoth;
    const bool City = Planet == EStarflightWorld::Coruscant;
    const FVector Wind = Dust ? FVector(2000,5400,20) : Snow ? FVector(360,2350,-960) : FVector(560,520,-6100);
    const FLinearColor Hue = Dust ? FLinearColor(0.76,0.39,0.16) : Snow ? FLinearColor(0.88,0.96,1) : FLinearColor(0.46,0.67,0.82);
    Fog->SetFogDensity((City ? 0.006f : 0.007f) + Gust*(Dust ? 0.018f : Snow ? 0.020f : 0.012f));
    const auto* Controller = Cast<APlayerController>(Ship.GetController());
    FVector Camera = Ship.GetActorLocation();
    FRotator View = Ship.GetActorRotation();
    if (Controller) Controller->GetPlayerViewPoint(Camera,View);
    const FVector CameraShift = MeshReady ? Camera - LastCamera : FVector::ZeroVector;
    LastCamera = Camera;
    const FVector Forward = View.Vector();
    const FVector Right = FRotationMatrix(View).GetUnitAxis(EAxis::Y);
    const FVector Up = FRotationMatrix(View).GetUnitAxis(EAxis::Z);
    const FVector ScreenWind = Wind - FVector::DotProduct(Wind,Forward) * Forward;
    const FVector Along = ScreenWind.GetSafeNormal(UE_SMALL_NUMBER,Up);
    const FVector Across = FVector::CrossProduct(Forward,Along).GetSafeNormal(UE_SMALL_NUMBER,Right);

    for (int32 Index=0; Index<Particles.Num(); ++Index) {
        auto& Particle = Particles[Index];
        Particle.Offset += Wind*(0.55+Gust)*Delta - CameraShift;
        for (int32 Axis=0; Axis<3; ++Axis) {
            if (FMath::Abs(Particle.Offset[Axis]) > FieldRadius) {
                const double Width = FieldRadius*2;
                Particle.Offset[Axis] -= FMath::FloorToDouble((Particle.Offset[Axis]+FieldRadius)/Width)*Width;
            }
        }
        const FVector P = Camera + Particle.Offset;
        const float Distance = Particle.Offset.Length();
        const float NearFade = FMath::Clamp((Distance-125)/480.f,0.f,1.f);
        const float FarFade = FMath::Clamp((FieldRadius*1.24f-Distance)/1250.f,0.f,1.f);
        const float Alpha = NearFade*FarFade*Particle.Brightness*(0.35f+Gust*0.36f);
        const float Width = (Dust ? 9.0f : Snow ? 5.5f : 1.7f)*Particle.Size;
        const float Length = (Dust ? 64.f : Snow ? 15.f : 50.f)*Particle.Size;
        const FVector A = Across*Width, B = Along*Length;
        const int32 Base = Index*4;
        Vertices[Base] = P-A-B*0.45f;
        Vertices[Base+1] = P+A-B*0.45f;
        Vertices[Base+2] = P+A*0.5f+B;
        Vertices[Base+3] = P-A*0.5f+B;
        const float LightLevel = City ? 0.12f : 1.f;
        const FLinearColor Tint(Hue.R*LightLevel,Hue.G*LightLevel,Hue.B*LightLevel,Alpha);
        Colors[Base] = Colors[Base+1] = Tint;
        Colors[Base+2] = Colors[Base+3] = FLinearColor(Tint.R,Tint.G,Tint.B,0);
    }
    if (!MeshReady) {
        Precipitation->CreateMeshSection_LinearColor(0,Vertices,Indices,{},{},Colors,{},false);
        MeshReady = true;
    } else {
        Precipitation->UpdateMeshSection_LinearColor(0,Vertices,{},{},Colors,{});
    }
}

FVector2D AStarflightWeather::Slope(FVector2D P) const {
    constexpr float D = 18;
    return FVector2D(Region->FlightSurface(P.X+D,P.Y)-Region->FlightSurface(P.X-D,P.Y),
                     Region->FlightSurface(P.X,P.Y+D)-Region->FlightSurface(P.X,P.Y-D))/(2*D);
}

bool AStarflightWeather::ReleaseRocks(const AStarflightPawn& Ship) {
    if (Boulders.Num() + 3 > MaxBoulders) return false;
    const auto Origin = Ship.Flight.position;
    const auto Facing = Ship.Flight.Forward();
    FVector2D Forward(Facing.x,Facing.z);
    if (!Forward.Normalize()) Forward=FVector2D(0,-1);
    const FVector2D Side(-Forward.Y,Forward.X);
    const FVector2D Centre(Origin.x,Origin.z);
    FVector2D Start;
    float BestSlope = 0.28f;
    for (int32 Index=0; Index<42; ++Index) {
        const float Sign = Index % 2 ? -1.f : 1.f;
        const FVector2D Try = Centre + Forward*Random.FRandRange(390,1500)
            + Side*Sign*Random.FRandRange(320,1260);
        const float Height = Region->FlightSurface(Try.X,Try.Y);
        if (!Region->Contains({float(Try.X),Height,float(Try.Y)})) continue;
        if (Height<Origin.y-380 || Height>Origin.y+650) continue;
        const float Grade = Slope(Try).Length();
        if (Grade > BestSlope) {
            Start = Try;
            BestSlope = Grade;
        }
    }
    if (BestSlope <= 0.28f) return false;
    for (int32 Index=0; Index<3; ++Index) {
        const FVector2D P = Start+Side*(Index-1)*38 + Forward*(Index-1)*20;
        const float Radius = Random.FRandRange(7,17);
        const FVector2D Direction = -Slope(P).GetSafeNormal();
        Boulders.Add({P,Direction*Random.FRandRange(5,10),FQuat::Identity,Radius,0});
    }
    UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_WEATHER: rockslide rolling on %s"),WorldName(Planet));
    return true;
}

void AStarflightWeather::UpdateRocks(AStarflightPawn& Ship, float Delta) {
    Ship.RockWarning = false;
    const UStaticMesh* Stone = Rocks->GetStaticMesh();
    if (!Stone) return;
    const FVector CurrentShip = Ship.GetActorLocation();
    // Teleports can occur on restart. Do not test a sweep across a teleport.
    const FVector PreviousShip = FVector::DistSquared(CurrentShip,LastShip)<FMath::Square(8000.0)
        ? LastShip : CurrentShip;
    LastShip = CurrentShip;
    RockClock -= Delta;
    if (RockClock <= 0 && !Ship.Crashed) RockClock = ReleaseRocks(Ship) ? RockPeriod : 4.f;
    for (int32 Index=Boulders.Num()-1; Index>=0; --Index) {
        auto& Rock = Boulders[Index];
        Rock.Age += Delta;
        const FVector2D Grade = Slope(Rock.Position);
        Rock.Velocity = (Rock.Velocity - Grade*14.0f*Delta)*FMath::Exp(-0.13f*Delta);
        Rock.Velocity = Rock.Velocity.GetSafeNormal() * FMath::Min(Rock.Velocity.Length(),39.0);
        const FVector2D Old = Rock.Position;
        Rock.Position += Rock.Velocity*Delta;
        const float Ground = Region->FlightSurface(Rock.Position.X,Rock.Position.Y);
        const starflight::Vec3 Position{float(Rock.Position.X),Ground+Rock.Radius*0.68f,float(Rock.Position.Y)};
        const FVector Point = ToUE(Position);
        const FVector Axis = FVector::CrossProduct(FVector::UpVector,
            ToUE({float(Rock.Velocity.X),0,float(Rock.Velocity.Y)})).GetSafeNormal();
        if (!Axis.IsNearlyZero()) {
            Rock.Rotation = (FQuat(Axis,(Rock.Position-Old).Length()/Rock.Radius)*Rock.Rotation).GetNormalized();
        }
        const float Distance = (Ship.Flight.position-Position).Length();
        Ship.RockWarning |= Distance < 410 && Rock.Velocity.Length()>2;
        const float OldGround = Region->FlightSurface(Old.X,Old.Y);
        const FVector PreviousRock = ToUE({float(Old.X),OldGround+Rock.Radius*0.68f,float(Old.Y)});
        const double SeparationSquared = FMath::PointDistToSegmentSquared(FVector::ZeroVector,
            PreviousShip-PreviousRock,CurrentShip-Point);
        if (SeparationSquared < FMath::Square((Rock.Radius+Ship.GetSimpleCollisionRadius()/100)*100.0) && !Ship.Crashed) {
            Ship.Crashed = true;
            Ship.RockImpact = true;
            Ship.Throttle = 0;
            Ship.Flight.velocity = {};
            Ship.Flight.airspeed = 0;
        }
        // Leave settled rocks visible until the player has passed them.
        if (Rock.Age > RockLife && (Distance > 1800 || !Region->Contains(Position))) Boulders.RemoveAtSwap(Index);
    }
    const bool Rebuild = Rocks->GetInstanceCount() != Boulders.Num();
    if (Rebuild) Rocks->ClearInstances();
    const FBoxSphereBounds Bounds = Stone->GetBounds();
    for (int32 Index=0; Index<Boulders.Num(); ++Index) {
        const auto& Rock = Boulders[Index];
        const FVector Position = ToUE({float(Rock.Position.X),
            Region->FlightSurface(Rock.Position.X,Rock.Position.Y)+Rock.Radius*0.68f,float(Rock.Position.Y)});
        const FVector Scale(Rock.Radius*100/Bounds.SphereRadius);
        const FTransform Transform(Rock.Rotation,Position-Rock.Rotation.RotateVector(Bounds.Origin*Scale),Scale);
        if (Rebuild) Rocks->AddInstance(Transform);
        else Rocks->UpdateInstanceTransform(Index,Transform,false,Index==Boulders.Num()-1,true);
    }
}
