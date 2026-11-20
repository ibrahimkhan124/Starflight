#pragma once
#include "CoreMinimal.h"
#include "Core/FlightCore.h"

class UWorld;
class UMaterialInterface;
class UExponentialHeightFogComponent;

enum class EStarflightWorld : uint8 { Hoth, Tatooine, Endor, Coruscant };

inline FVector ToUE(starflight::Vec3 Position) {
    const auto Converted = starflight::ToUnreal(Position);
    return FVector(Converted.x, Converted.y, Converted.z);
}

const TCHAR* WorldName(EStarflightWorld World);
UMaterialInterface* ScenicMaterial(const TCHAR* Name);
UExponentialHeightFogComponent* BuildSky(UWorld& World, EStarflightWorld Planet);
