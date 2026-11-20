#include "CityTraffic.h"
#include "Fleet.hpp"
#include "Renderer.hpp"
#include "Components/StaticMeshComponent.h"

AStarflightCityTraffic::AStarflightCityTraffic() {
    PrimaryActorTick.bCanEverTick=true;
    PrimaryActorTick.TickInterval=1.f/30.f;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("TrafficLanes")));
}

void AStarflightCityTraffic::BeginPlay() {
    Super::BeginPlay();
    constexpr const TCHAR* Models[]={TEXT("meridian"),TEXT("imperialShuttle"),TEXT("razorCrest"),TEXT("millenniumFalcon")};
    TArray<UStaticMesh*> Fleet;
    for (const auto* Model : Models) {
        if (auto* Mesh=LoadFleetShip(FleetIndex(Model))) Fleet.Add(Mesh);
    }
    if (Fleet.IsEmpty()) return;
    for (int32 Index=0; Index<18; ++Index) {
        auto* Ship=NewObject<UStaticMeshComponent>(this);
        AddInstanceComponent(Ship);
        Ship->SetupAttachment(GetRootComponent());
        Ship->SetCollisionProfileName(TEXT("NoCollision"));
        Ship->SetStaticMesh(Fleet[Index%Fleet.Num()]);
        Ship->SetRelativeScale3D(FVector(1.70+Index%3*0.3));
        Ship->SetCastShadow(false);
        Ship->RegisterComponent();
        Ships.Add(Ship);
        // Longitudinal lanes begin ahead of the arrival, offset from the player's line.
        const bool Crossing=Index>=8;
        const float Direction=Index%2==0 ? 1.f : -1.f;
        Routes.Add({Crossing ? (-5200.f+(Index-8)*1200) : (7460.f-(Index/2)*950),
            Crossing ? (4320.f+(Index%6)*480) : Direction*(480.f+(Index/2)*480),
            Crossing ? 1020.f+Index%3*62.f : 275.f+Index%4*75.f,
            Direction*(106.f+Index%3*16.f),Crossing});
    }
    Tick(0);
    UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_TRAFFIC: %d ships in Coruscant lanes"),Ships.Num());
}

void AStarflightCityTraffic::Tick(float Delta) {
    Super::Tick(Delta);
    for (int32 Index=0; Index<Routes.Num(); ++Index) {
        auto& Route=Routes[Index];
        Route.Along+=Route.Speed*FMath::Min(Delta,0.1f);
        if (Route.Along>11800) Route.Along-=23600;
        if (Route.Along< -11800) Route.Along+=23600;
        const starflight::Vec3 P=Route.CrossCity ? starflight::Vec3{Route.Along,Route.Altitude,Route.Lane}
            : starflight::Vec3{Route.Lane,Route.Altitude,Route.Along};
        const float Direction=Route.Speed>0 ? 1.f : -1.f;
        const float Yaw=Route.CrossCity ? (Direction>0 ? 180.f : 0.f) : (Direction>0 ? 270.f : 90.f);
        Ships[Index]->SetWorldLocationAndRotation(ToUE(P),FRotator(0,Yaw,0));
    }
}
