#pragma once

#include "CoreMinimal.h"
#include "Renderer.hpp"

class AStarflightRegion;

struct FLakeBasin {
    FVector2D Centre;
    FVector2D Radii;
    float Level;
    float Depth;

    float Distance(float X, float Z) const;
    float Cut(float Height,float X,float Z) const;
};

TConstArrayView<FLakeBasin> WorldLakes(EStarflightWorld World);
void AddLakeFeatures(AStarflightRegion& Region, EStarflightWorld World,
    const TArray<FVector>& Terrain,const TArray<int32>& Triangles);
void AddCityRoads(AStarflightRegion& Region);
