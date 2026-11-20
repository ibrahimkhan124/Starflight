#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PlanetWeather.generated.h"

class AStarflightPawn;
class AStarflightRegion;
class UExponentialHeightFogComponent;
class UInstancedStaticMeshComponent;
class UProceduralMeshComponent;
enum class EStarflightWorld : uint8;

UCLASS()
class AStarflightWeather : public AActor {
    GENERATED_BODY()
public:
    AStarflightWeather();
    void Configure(AStarflightRegion& Ground, EStarflightWorld World, UExponentialHeightFogComponent& Haze);
    virtual void Tick(float DeltaSeconds) override;

private:
    struct FParticle {
        FVector Offset;
        float Size;
        float Brightness;
    };
    struct FBoulder {
        FVector2D Position;
        FVector2D Velocity;
        FQuat Rotation;
        float Radius;
        float Age;
    };

    UPROPERTY() TObjectPtr<AStarflightRegion> Region;
    UPROPERTY() TObjectPtr<UProceduralMeshComponent> Precipitation;
    UPROPERTY() TObjectPtr<UInstancedStaticMeshComponent> Rocks;
    UPROPERTY() TObjectPtr<UExponentialHeightFogComponent> Fog;
    TArray<FParticle> Particles;
    TArray<FBoulder> Boulders;
    TArray<FVector> Vertices;
    TArray<int32> Indices;
    TArray<FLinearColor> Colors;
    FRandomStream Random;
    EStarflightWorld Planet;
    float Elapsed = 0;
    float RockClock = 0;
    bool MeshReady = false;
    FVector LastCamera = FVector::ZeroVector;
    FVector LastShip = FVector::ZeroVector;

    void UpdateWeather(const AStarflightPawn& Ship, float Delta, float Gust);
    void UpdateRocks(AStarflightPawn& Ship, float Delta);
    bool ReleaseRocks(const AStarflightPawn& Ship);
    FVector2D Slope(FVector2D Position) const;
};
