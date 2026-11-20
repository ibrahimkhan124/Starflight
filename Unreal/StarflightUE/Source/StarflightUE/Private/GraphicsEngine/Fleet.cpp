#include "Fleet.hpp"

#include "Engine/StaticMesh.h"

namespace {
constexpr FFleetShip Fleet[] = {
    {TEXT("peregrine"),TEXT("Peregrine Survey Craft"),{},1.5f,0.9f,9.f,11.f},
#include "FleetProfiles.inl"
};
}

TConstArrayView<FFleetShip> FlightFleet() { return MakeArrayView(Fleet); }

const FFleetShip& ShipProfile(int32 Index) {
    return FlightFleet().IsValidIndex(Index) ? Fleet[Index] : Fleet[0];
}

int32 FleetIndex(FStringView Id) {
    const auto Ships=FlightFleet();
    for (int32 Index=0; Index<Ships.Num(); ++Index) {
        if (Id.Equals(Ships[Index].Id,ESearchCase::IgnoreCase)) return Index;
    }
    return 0;
}

UStaticMesh* LoadFleetShip(int32 Index) {
    if (Index==0) return LoadObject<UStaticMesh>(nullptr,TEXT("/Game/Starflight/Ships/SM_Peregrine.SM_Peregrine"));
    const FString Mesh=FString::Printf(TEXT("SM_Fleet_%s"),ShipProfile(Index).Id);
    return LoadObject<UStaticMesh>(nullptr,*FString::Printf(TEXT("/Game/Starflight/Fleet/%s.%s"),*Mesh,*Mesh));
}
