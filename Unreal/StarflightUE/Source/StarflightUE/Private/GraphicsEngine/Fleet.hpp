#pragma once

#include "CoreMinimal.h"
#include "Core/FlightCore.h"

class UStaticMesh;

struct FFleetShip {
    const TCHAR* Id;
    const TCHAR* Name;
    starflight::Handling Handling;
    float BodyRadius;
    float CityRadius;
    float Length;
    float Span;
};

TConstArrayView<FFleetShip> FlightFleet();
const FFleetShip& ShipProfile(int32 Index);
int32 FleetIndex(FStringView Id);
UStaticMesh* LoadFleetShip(int32 Index);
