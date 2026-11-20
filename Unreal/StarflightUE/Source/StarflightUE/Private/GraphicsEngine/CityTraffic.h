#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "CityTraffic.generated.h"

class UStaticMeshComponent;

UCLASS()
class AStarflightCityTraffic : public AActor {
    GENERATED_BODY()
public:
    AStarflightCityTraffic();
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;

private:
    struct FRoute {
        float Along;
        float Lane;
        float Altitude;
        float Speed;
        bool CrossCity;
    };
    UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Ships;
    TArray<FRoute> Routes;
};
