#include "Renderer.hpp"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/World.h"
#include "Engine/StaticMesh.h"
#include "Engine/PostProcessVolume.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInterface.h"
#include "ProceduralMeshComponent.h"

const TCHAR* WorldName(EStarflightWorld World) {
    switch (World) {
        case EStarflightWorld::Hoth: return TEXT("Hoth");
        case EStarflightWorld::Tatooine: return TEXT("Tatooine");
        case EStarflightWorld::Endor: return TEXT("Endor");
        case EStarflightWorld::Coruscant: return TEXT("Coruscant");
    }
    return TEXT("Hoth");
}

UMaterialInterface* ScenicMaterial(const TCHAR* Name) {
    return LoadObject<UMaterialInterface>(nullptr,
        *FString::Printf(TEXT("/Game/Starflight/Materials/%s.%s"),Name,Name));
}

UExponentialHeightFogComponent* BuildSky(UWorld& World, EStarflightWorld Planet) {
    const bool City = Planet == EStarflightWorld::Coruscant;
    const bool Desert = Planet == EStarflightWorld::Tatooine;
    const bool Forest = Planet == EStarflightWorld::Endor;
    const float Elevation = City ? 6 : Desert ? 26 : Forest ? 29 : 44;
    const float Azimuth = Desert ? 134 : City ? 105 : 34;
    auto* Sun = World.SpawnActor<ADirectionalLight>(FVector::ZeroVector,FRotator(-Elevation,Azimuth,0));
    auto* Light = CastChecked<UDirectionalLightComponent>(Sun->GetLightComponent());
    Light->SetMobility(EComponentMobility::Movable);
    Light->SetIntensity(City ? 650 : 32000);
    Light->SetLightColor(Desert ? FLinearColor(1,0.79,0.59) : City ? FLinearColor(0.50,0.59,1) : Forest ? FLinearColor(1,0.92,0.76) : FLinearColor(0.96,0.99,1));
    Light->bAtmosphereSunLight = true;
    Light->MarkRenderStateDirty();

    if (City) {
        auto* Dome = World.SpawnActor<AActor>();
        Dome->SetActorEnableCollision(false);
        auto* Surface = NewObject<UStaticMeshComponent>(Dome,TEXT("NightSky"));
        Dome->SetRootComponent(Surface);
        Dome->AddInstanceComponent(Surface);
        Surface->SetCollisionProfileName(TEXT("NoCollision"));
        Surface->SetGenerateOverlapEvents(false);
        Surface->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,TEXT("/Engine/BasicShapes/Sphere.Sphere")));
        Surface->SetRelativeScale3D(FVector(62000));
        Surface->SetMaterial(0,ScenicMaterial(TEXT("M_CitySky")));
        Surface->SetCastShadow(false);
        Surface->RegisterComponent();

        auto* Grade = World.SpawnActor<APostProcessVolume>();
        Grade->bUnbound = true;
        Grade->Settings.bOverride_AutoExposureBias = true;
        Grade->Settings.AutoExposureBias = -1.75f;
    } else {
        World.SpawnActor<ASkyAtmosphere>();
    }
    auto* Sky = World.SpawnActor<ASkyLight>();
    auto* Ambient = Sky->GetLightComponent();
    Ambient->SetMobility(EComponentMobility::Movable);
    Ambient->SetIntensity(City ? 0.40f : 1.25f);
    Ambient->RecaptureSky();

    auto* Fog = World.SpawnActor<AExponentialHeightFog>();
    auto* Haze = Fog->GetComponent();
    Haze->SetFogDensity(City ? 0.010f : Forest ? 0.007f : 0.010f);
    Haze->SetFogHeightFalloff(0.045f);
    Haze->SetFogInscatteringColor(City ? FLinearColor(0.033,0.048,0.14) :
        Desert ? FLinearColor(0.64,0.35,0.19) :
        Forest ? FLinearColor(0.28,0.37,0.28) : FLinearColor(0.42,0.56,0.73));
    Haze->SetStartDistance(Forest ? 1800 : 26000);
#if PLATFORM_MAC
    if (Forest) {
        Haze->SetVolumetricFog(true);
        Haze->SetVolumetricFogDistance(310000);
        Haze->SetVolumetricFogScatteringDistribution(0.68f);
        Haze->SetVolumetricFogExtinctionScale(0.48f);
        Light->SetVolumetricScatteringIntensity(1.18f);
        Light->SetDynamicShadowDistanceMovableLight(185000);
        Light->SetDynamicShadowCascades(3);
    }
#endif

    UMaterialInterface* CloudMaterial = ScenicMaterial(TEXT("M_CloudDeck"));
    if (City || Desert || !CloudMaterial) return Haze;
    auto* Clouds = World.SpawnActor<AActor>();
    auto* Deck = NewObject<UProceduralMeshComponent>(Clouds,TEXT("CloudDeck"));
    Clouds->SetRootComponent(Deck);
    Clouds->AddInstanceComponent(Deck);
    Deck->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Deck->SetCastShadow(false);
    const float Far = 2300000;
    const float Altitude = Forest ? 178000 : 235000;
    const TArray<FVector> Vertices = {{-Far,-Far,Altitude},{Far,-Far,Altitude},{Far,Far,Altitude},{-Far,Far,Altitude}};
    Deck->CreateMeshSection_LinearColor(0,Vertices,{0,1,2,0,2,3},{},{},{},{},false);
    Deck->SetMaterial(0,CloudMaterial);
    Deck->RegisterComponent();
    return Haze;
}
