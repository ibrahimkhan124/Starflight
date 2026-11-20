#pragma once
#include "CoreMinimal.h"
#include "InputCoreTypes.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "Core/FlightCore.h"
#include "StarflightPrototype.generated.h"

class USphereComponent;
class USpringArmComponent;
class UCameraComponent;
class UStaticMeshComponent;
class UProceduralMeshComponent;
enum class EStarflightWorld : uint8;

UCLASS()
class STARFLIGHTUE_API AStarflightRegion : public AActor {
    GENERATED_BODY()
public:
    AStarflightRegion();
    bool Prepare(EStarflightWorld Planet);
    float Surface(float X, float Z) const;
    float FlightSurface(float X, float Z) const;
    bool Contains(starflight::Vec3 P) const { return FMath::Abs(P.x)<=Extent && FMath::Abs(P.z)<=Extent; }
    starflight::Vec3 Arrival{0,430,8400};
private:
    EStarflightWorld World{};
    TArray<float> Heights;
    float Extent=12000;
    int32 Cells=0;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UProceduralMeshComponent> TerrainMesh;
};

UCLASS()
class STARFLIGHTUE_API AStarflightPawn : public APawn {
    GENERATED_BODY()
public:
    AStarflightPawn();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;
    virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
    float Throttle=0;
    bool Crashed=false;
    bool RockWarning=false,RockImpact=false;
    starflight::State Flight;
    void RestartFlight();
    int32 ActiveShip = 0;
    float LowFlightPoints = 0;
    bool Aerodynamic = false;
    bool WaterImpact = false;
    UPROPERTY() TObjectPtr<AStarflightRegion> Region;
private:
    UPROPERTY(VisibleAnywhere) TObjectPtr<USphereComponent> Collision;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Hull;
    UPROPERTY(VisibleAnywhere) TObjectPtr<USpringArmComponent> Boom;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UCameraComponent> Chase;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UCameraComponent> Cockpit;
    float Accumulator=0,PitchAxis=0,RollAxis=0,YawAxis=0,ThrottleAxis=0;
    FVector2D StickOrigin=FVector2D::ZeroVector,TouchAxes=FVector2D::ZeroVector;
    int32 StickFinger=INDEX_NONE,ThrottleFinger=INDEX_NONE;
    bool CockpitActive=false;
    float FlightTime = 0;
    void ApplyShip(int32 Index);
    void BrowseShip(FKey Key);
    void ToggleAerodynamics();
    void ClickFlightHUD();
    void VisitLake();
    int32 NextLake=0;
#if !UE_BUILD_SHIPPING
    int32 SmokeFrame=0;
    bool SmokeEnabled=false,SmokeFailed=false;
    void TickSmokeCheck();
#endif
    void SetPitch(float V) { PitchAxis=V; }
    void SetRoll(float V) { RollAxis=V; }
    void SetYaw(float V) { YawAxis=V; }
    void SetThrottleAxis(float V) { ThrottleAxis=V; }
    void ToggleCamera();
    void TogglePause();
    void SelectWorld(EStarflightWorld Planet,int32 Ship=INDEX_NONE);
    void ShowFlightPlanner();
    void TouchBegin(ETouchIndex::Type Finger,FVector Location);
    void TouchMove(ETouchIndex::Type Finger,FVector Location);
    void TouchEnd(ETouchIndex::Type Finger,FVector Location);
};

UCLASS()
class STARFLIGHTUE_API AStarflightHUD : public AHUD {
    GENERATED_BODY()
public:
    virtual void DrawHUD() override;
};

UCLASS()
class STARFLIGHTUE_API AStarflightGameMode : public AGameModeBase {
    GENERATED_BODY()
public:
    AStarflightGameMode();
    virtual void InitGame(const FString& MapName,const FString& Options,FString& Error) override;
    virtual void StartPlay() override;
    EStarflightWorld Planet;
    int32 SelectedShip=0;
};
