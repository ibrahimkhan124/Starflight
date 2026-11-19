#include "StarflightPrototype.h"
#include "ProceduralMeshComponent.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "GameFramework/PlayerController.h"
#include "Components/InputComponent.h"
#include "Engine/Canvas.h"
#include "Engine/World.h"
#include "Engine/StaticMesh.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Engine/SkyAtmosphere.h"
#include "Engine/ExponentialHeightFog.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Materials/MaterialInterface.h"
#include "UObject/ConstructorHelpers.h"
#include "EngineUtils.h"
#include "Kismet/GameplayStatics.h"

static FVector ToUE(starflight::Vec3 P) { const auto V=starflight::ToUnreal(P);return FVector(V.x,V.y,V.z); }

AStarflightRegion::AStarflightRegion() {
    TerrainMesh=CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("PreparedMountainRegion"));
    SetRootComponent(TerrainMesh);TerrainMesh->SetMobility(EComponentMobility::Static);
    TerrainMesh->bUseAsyncCooking=false; // Complete the single region before flight starts.
    TerrainMesh->bUseComplexAsSimpleCollision=true;
    TerrainMesh->SetCollisionProfileName(TEXT("BlockAll"));
}
void AStarflightRegion::BeginPlay() {
    Super::BeginPlay();
    const starflight::Terrain Field;
    constexpr int32 NX=96,NZ=200,Stride=NX+1;
    TArray<FVector> Vertices,Normals;
    TArray<FVector2D> UV;
    TArray<FLinearColor> Colors;
    TArray<int32> Triangles;
    TArray<FProcMeshTangent> Tangents;
    Vertices.Reserve((NX+1)*(NZ+1));Normals.Reserve((NX+1)*(NZ+1));
    for (int32 Z=0;Z<=NZ;++Z) for(int32 X=0;X<=NX;++X) {
        const float PX=Field.MinX+X*Field.Spacing,PZ=Field.MinZ+Z*Field.Spacing,H=Field.Height(PX,PZ);
        Vertices.Add(ToUE({PX,H,PZ}));
        const FVector N=ToUE({Field.Height(PX-2,PZ)-Field.Height(PX+2,PZ),4,Field.Height(PX,PZ-2)-Field.Height(PX,PZ+2)}).GetSafeNormal();
        Normals.Add(N);UV.Add(FVector2D(PX/160,PZ/160));
        const FLinearColor Low(0.12f,0.23f,0.13f),Rock(0.26f,0.29f,0.30f),Snow(0.8f,0.87f,0.92f);
        const float SnowMix=FMath::Clamp((H-550)/280,0.0f,1.0f);
        Colors.Add(FMath::Lerp(FMath::Lerp(Low,Rock,FMath::Clamp((H-160)/400,0.0f,1.0f)),Snow,SnowMix));
    }
    for(int32 Z=0;Z<NZ;++Z) for(int32 X=0;X<NX;++X) {
        const int32 A=Z*Stride+X,B=A+1,C=A+Stride,D=C+1;
        Triangles.Append({A,B,C,B,D,C});
    }
    TerrainMesh->CreateMeshSection_LinearColor(0,Vertices,Triangles,Normals,UV,Colors,Tangents,true);
    if (auto* Paint=LoadObject<UMaterialInterface>(nullptr,TEXT("/Game/Starflight/Materials/M_Terrain.M_Terrain"))) TerrainMesh->SetMaterial(0,Paint);
    else UE_LOG(LogTemp,Warning,TEXT("Run Tools/create_prototype_assets.py in Unreal Editor to create the terrain material."));
}

AStarflightPawn::AStarflightPawn() {
    PrimaryActorTick.bCanEverTick=true;
    Collision=CreateDefaultSubobject<USphereComponent>(TEXT("HullCollision"));
    Collision->InitSphereRadius(150);Collision->SetCollisionProfileName(TEXT("Pawn"));SetRootComponent(Collision);
    Hull=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderHull"));Hull->SetupAttachment(Collision);
    Wing=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderWing"));Wing->SetupAttachment(Collision);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    if(Cube.Succeeded()) { Hull->SetStaticMesh(Cube.Object);Wing->SetStaticMesh(Cube.Object); }
    Hull->SetRelativeScale3D(FVector(6,1.2,0.7));Wing->SetRelativeScale3D(FVector(1.4,8,0.15));
    Hull->SetCollisionEnabled(ECollisionEnabled::NoCollision);Wing->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Boom=CreateDefaultSubobject<USpringArmComponent>(TEXT("ChaseArm"));Boom->SetupAttachment(Collision);
    Boom->TargetArmLength=1800;Boom->SocketOffset=FVector(0,0,500);Boom->bDoCollisionTest=true;
    Chase=CreateDefaultSubobject<UCameraComponent>(TEXT("ChaseCamera"));Chase->SetupAttachment(Boom);
    Cockpit=CreateDefaultSubobject<UCameraComponent>(TEXT("CockpitCamera"));Cockpit->SetupAttachment(Collision);
    Cockpit->SetRelativeLocation(FVector(320,0,90));Cockpit->SetAutoActivate(false);
}
void AStarflightPawn::BeginPlay() { Super::BeginPlay();RestartFlight(); }
void AStarflightPawn::RestartFlight() {
    Flight=starflight::State{};Throttle=0;Crashed=false;Accumulator=0;
    PitchAxis=RollAxis=YawAxis=ThrottleAxis=0;TouchAxes=FVector2D::ZeroVector;
    StickFinger=ThrottleFinger=INDEX_NONE;
    SetActorLocationAndRotation(ToUE(Flight.position),FRotator::ZeroRotator,false,nullptr,ETeleportType::TeleportPhysics);
}
void AStarflightPawn::Tick(float Delta) {
    Super::Tick(Delta);
    if(Crashed || !FMath::IsFinite(Delta) || Delta<=0) return;
    Throttle=FMath::Clamp(Throttle+ThrottleAxis*FMath::Min(Delta,0.1f)*0.5f,-1.0f,1.0f);
    Accumulator+=FMath::Min(Delta,0.1f);
    const starflight::Terrain Field;
    while(Accumulator>=starflight::Step && !Crashed) {
        starflight::Input Input;
        Input.pitch=FMath::Clamp(PitchAxis+float(TouchAxes.Y),-1.0f,1.0f);
        Input.roll=FMath::Clamp(RollAxis+float(TouchAxes.X),-1.0f,1.0f);
        Input.yaw=YawAxis;Input.throttle=Throttle;
        starflight::Advance(Flight,Input,starflight::Step);
        FHitResult Hit;
        SetActorLocationAndRotation(ToUE(Flight.position),FRotator(FMath::RadiansToDegrees(Flight.pitch),FMath::RadiansToDegrees(Flight.heading),FMath::RadiansToDegrees(Flight.roll)),true,&Hit);
        // The physics sweep uses the exact visible triangles, not the smooth height recipe.
        Crashed=Hit.bBlockingHit || !Field.Contains(Flight.position);
        if(Crashed) {
            const auto P=GetActorLocation();Flight.position=starflight::FromUnreal({float(P.X),float(P.Y),float(P.Z)});
            Flight.velocity={};Throttle=0;
        }
        Accumulator-=starflight::Step;
    }
}
void AStarflightPawn::ToggleCamera() {
    CockpitActive=!CockpitActive;Cockpit->SetActive(CockpitActive);Chase->SetActive(!CockpitActive);
    Hull->SetVisibility(!CockpitActive);Wing->SetVisibility(!CockpitActive);
}
void AStarflightPawn::TogglePause() {
    if(auto* PC=Cast<APlayerController>(GetController())) PC->SetPause(!UGameplayStatics::IsGamePaused(this));
}
void AStarflightPawn::SetupPlayerInputComponent(UInputComponent* Input) {
    Super::SetupPlayerInputComponent(Input);
    Input->BindAxis("Pitch",this,&AStarflightPawn::SetPitch);Input->BindAxis("Roll",this,&AStarflightPawn::SetRoll);
    Input->BindAxis("Yaw",this,&AStarflightPawn::SetYaw);Input->BindAxis("Throttle",this,&AStarflightPawn::SetThrottleAxis);
    Input->BindAction("Camera",IE_Pressed,this,&AStarflightPawn::ToggleCamera);
    Input->BindAction("Restart",IE_Pressed,this,&AStarflightPawn::RestartFlight);
    auto& Pause=Input->BindAction("Pause",IE_Pressed,this,&AStarflightPawn::TogglePause);Pause.bExecuteWhenPaused=true;
    auto& Touch=Input->BindTouch(IE_Pressed,this,&AStarflightPawn::TouchBegin);Touch.bExecuteWhenPaused=true;
    Input->BindTouch(IE_Repeat,this,&AStarflightPawn::TouchMove);
    Input->BindTouch(IE_Released,this,&AStarflightPawn::TouchEnd);
}
void AStarflightPawn::TouchBegin(ETouchIndex::Type Finger,FVector P) {
    auto* PC=Cast<APlayerController>(GetController());if(!PC) return;
    int32 W=0,H=0;PC->GetViewportSize(W,H);if(W<=0 || H<=0) return;
    if(P.Y<H*0.20 && P.X>W*0.55 && P.X<=W*0.75) { TogglePause();return; }
    if(UGameplayStatics::IsGamePaused(this)) return;
    if(P.Y<H*0.20 && P.X>W*0.75) { ToggleCamera();return; }
    if(Crashed) { RestartFlight();return; }
    if(P.X<W*0.48 && P.Y>H*0.45 && StickFinger==INDEX_NONE) { StickFinger=int32(Finger);StickOrigin=FVector2D(P.X,P.Y); }
    else if(P.X>W*0.85 && ThrottleFinger==INDEX_NONE) { ThrottleFinger=int32(Finger);TouchMove(Finger,P); }
}
void AStarflightPawn::TouchMove(ETouchIndex::Type Finger,FVector P) {
    auto* PC=Cast<APlayerController>(GetController());if(!PC) return;
    int32 W=0,H=0;PC->GetViewportSize(W,H);if(W<=0 || H<=0) return;
    if(int32(Finger)==StickFinger) {
        const auto Delta=(FVector2D(P.X,P.Y)-StickOrigin)/FMath::Max(45.0f,float(H)*0.18f);
        TouchAxes=FVector2D(FMath::Clamp(Delta.X,-1.0,1.0),FMath::Clamp(Delta.Y,-1.0,1.0));
    }
    if(int32(Finger)==ThrottleFinger) Throttle=FMath::Clamp(1.0f-(float(P.Y)/float(H)-0.25f)/0.6f*2,-1.0f,1.0f);
}
void AStarflightPawn::TouchEnd(ETouchIndex::Type Finger,FVector) {
    if(int32(Finger)==StickFinger) { StickFinger=INDEX_NONE;TouchAxes=FVector2D::ZeroVector; }
    if(int32(Finger)==ThrottleFinger) ThrottleFinger=INDEX_NONE;
}
void AStarflightHUD::DrawHUD() {
    Super::DrawHUD();auto* Pawn=Cast<AStarflightPawn>(GetOwningPawn());if(!Pawn || !Canvas) return;
    const starflight::Terrain Field;
    DrawText(FString::Printf(TEXT("STARFLIGHT UE — PROTOTYPE  |  %.0f kt  |  Alt %.0f m  |  Ground %.0f m  |  Throttle %.0f%%"),Pawn->Flight.velocity.Length()*1.94384f,Pawn->Flight.position.y,Pawn->Flight.position.y-Field.Surface(Pawn->Flight.position.x,Pawn->Flight.position.z),Pawn->Throttle*100),FLinearColor::White,24,24);
    DrawText(TEXT("W/S pitch · A/D bank · Q/E rudder · R/F throttle · C camera · Esc pause · Enter restart"),FLinearColor::White,24,Canvas->ClipY-56);
    DrawText(TEXT("Touch: drag lower left to steer · right edge throttle · upper right camera"),FLinearColor::White,24,Canvas->ClipY-32);
    DrawRect(FLinearColor(0,0.5f,0.8f,0.18f),20,Canvas->ClipY*0.55f,Canvas->ClipX*0.34f,Canvas->ClipY*0.40f);
    DrawText(TEXT("STEER"),FLinearColor::White,30,Canvas->ClipY*0.58f);
    DrawRect(FLinearColor(0,0.5f,0.8f,0.3f),Canvas->ClipX*0.90f,Canvas->ClipY*0.25f,20,Canvas->ClipY*0.60f);
    DrawRect(FLinearColor::White,Canvas->ClipX*0.90f-5,Canvas->ClipY*(0.25f+(1-Pawn->Throttle)*0.3f),30,8);
    DrawText(TEXT("PAUSE"),FLinearColor::White,Canvas->ClipX*0.60f,Canvas->ClipY*0.12f);
    DrawText(TEXT("CAMERA"),FLinearColor::White,Canvas->ClipX*0.78f,Canvas->ClipY*0.12f);
    if(Pawn->Crashed) DrawText(TEXT("IMPACT / REGION EDGE — tap to restart, or press Enter"),FLinearColor::Red,Canvas->ClipX*0.20f,Canvas->ClipY*0.45f);
}
AStarflightGameMode::AStarflightGameMode() { bPauseable=true;DefaultPawnClass=AStarflightPawn::StaticClass();HUDClass=AStarflightHUD::StaticClass(); }
void AStarflightGameMode::StartPlay() {
    GetWorld()->SpawnActor<AStarflightRegion>();
    auto* Sun=GetWorld()->SpawnActor<ADirectionalLight>(FVector::ZeroVector,FRotator(-40,-35,0));
    if(auto* Light=Cast<UDirectionalLightComponent>(Sun->GetLightComponent())) { Light->SetMobility(EComponentMobility::Movable);Light->SetIntensity(50000);Light->bAtmosphereSunLight=true;Light->MarkRenderStateDirty(); }
    GetWorld()->SpawnActor<ASkyAtmosphere>();
    auto* Sky=GetWorld()->SpawnActor<ASkyLight>();Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);Sky->GetLightComponent()->SetIntensity(1);Sky->GetLightComponent()->RecaptureSky();
    auto* Fog=GetWorld()->SpawnActor<AExponentialHeightFog>();Fog->GetComponent()->SetFogDensity(0.002f);
    Super::StartPlay();
}
