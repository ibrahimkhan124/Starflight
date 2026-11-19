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

UCLASS()
class STARFLIGHTUE_API AStarflightRegion : public AActor {
    GENERATED_BODY()
public:
    AStarflightRegion();
    virtual void BeginPlay() override;
private:
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
    starflight::State Flight;
    void RestartFlight();
private:
    UPROPERTY(VisibleAnywhere) TObjectPtr<USphereComponent> Collision;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Hull;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Wing;
    UPROPERTY(VisibleAnywhere) TObjectPtr<USpringArmComponent> Boom;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UCameraComponent> Chase;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UCameraComponent> Cockpit;
    float Accumulator=0,PitchAxis=0,RollAxis=0,YawAxis=0,ThrottleAxis=0;
    FVector2D StickOrigin=FVector2D::ZeroVector,TouchAxes=FVector2D::ZeroVector;
    int32 StickFinger=INDEX_NONE,ThrottleFinger=INDEX_NONE;
    bool CockpitActive=false;
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
    virtual void StartPlay() override;
};
