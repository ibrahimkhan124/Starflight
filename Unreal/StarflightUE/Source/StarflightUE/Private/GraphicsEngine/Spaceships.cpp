#include "StarflightPrototype.h"
#include "Renderer.hpp"
#include "Apple/SwiftPlanner.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "GameFramework/PlayerController.h"
#include "Components/InputComponent.h"
#include "Engine/World.h"
#include "Engine/StaticMesh.h"
#include "UObject/ConstructorHelpers.h"
#include "EngineUtils.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "HAL/PlatformMisc.h"

AStarflightPawn::AStarflightPawn() {
    PrimaryActorTick.bCanEverTick=true;
    Collision=CreateDefaultSubobject<USphereComponent>(TEXT("HullCollision"));
    Collision->InitSphereRadius(150);Collision->SetCollisionProfileName(TEXT("Pawn"));SetRootComponent(Collision);
    Hull=CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Peregrine"));Hull->SetupAttachment(Collision);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Ship(TEXT("/Game/Starflight/Ships/SM_Peregrine.SM_Peregrine"));
    if(Ship.Succeeded()) Hull->SetStaticMesh(Ship.Object);
    Hull->SetRelativeRotation(FRotator(0,90,0));
    Hull->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Boom=CreateDefaultSubobject<USpringArmComponent>(TEXT("ChaseArm"));Boom->SetupAttachment(Collision);
    Boom->bInheritRoll=false;Boom->TargetArmLength=1800;Boom->SocketOffset=FVector(0,0,500);Boom->bDoCollisionTest=true;
    Chase=CreateDefaultSubobject<UCameraComponent>(TEXT("ChaseCamera"));Chase->SetupAttachment(Boom,USpringArmComponent::SocketName);
    Chase->SetRelativeRotation(FRotator(-5,0,0));
    Cockpit=CreateDefaultSubobject<UCameraComponent>(TEXT("CockpitCamera"));Cockpit->SetupAttachment(Collision);
    Cockpit->SetRelativeLocation(FVector(320,0,90));Cockpit->SetAutoActivate(false);
}
void AStarflightPawn::BeginPlay() {
    Super::BeginPlay();
    TActorIterator<AStarflightRegion> RegionIt(GetWorld());
    if (RegionIt) Region = *RegionIt;
    RestartFlight();
#if !UE_BUILD_SHIPPING
    SmokeEnabled=FParse::Param(FCommandLine::Get(),TEXT("StarflightSmoke"));
#endif
}
void AStarflightPawn::RestartFlight() {
    Flight=starflight::State{};
    if (Region) Flight.position=Region->Arrival;
    Throttle=0;Crashed=false;RockImpact=false;RockWarning=false;Accumulator=0;
    PitchAxis=RollAxis=YawAxis=ThrottleAxis=0;TouchAxes=FVector2D::ZeroVector;
    StickFinger=ThrottleFinger=INDEX_NONE;
    SetActorLocationAndRotation(ToUE(Flight.position),FRotator::ZeroRotator,false,nullptr,ETeleportType::TeleportPhysics);
}
void AStarflightPawn::Tick(float Delta) {
    Super::Tick(Delta);
#if !UE_BUILD_SHIPPING
    if(SmokeEnabled) TickSmokeCheck();
#endif
    if(Crashed || !FMath::IsFinite(Delta) || Delta<=0) return;
    Throttle=FMath::Clamp(Throttle+ThrottleAxis*FMath::Min(Delta,0.1f)*0.5f,-1.0f,1.0f);
    Accumulator+=FMath::Min(Delta,0.1f);
    while(Accumulator>=starflight::Step && !Crashed) {
        starflight::Input Input;
        Input.pitch=FMath::Clamp(PitchAxis+float(TouchAxes.Y),-1.0f,1.0f);
        Input.roll=FMath::Clamp(RollAxis+float(TouchAxes.X),-1.0f,1.0f);
        Input.yaw=YawAxis;Input.throttle=Throttle;
        starflight::Advance(Flight,Input,starflight::Step);
        FHitResult Hit;
        SetActorLocationAndRotation(ToUE(Flight.position),FRotator(FMath::RadiansToDegrees(Flight.pitch),FMath::RadiansToDegrees(Flight.heading),FMath::RadiansToDegrees(Flight.roll)),true,&Hit);
        // The physics sweep uses the exact visible triangles, not the smooth height recipe.
        Crashed=Hit.bBlockingHit || (Region && !Region->Contains(Flight.position));
        if(Crashed) {
            UE_LOG(LogTemp, Display, TEXT("STARFLIGHT_IMPACT: %s at %s"),
                Hit.bBlockingHit ? *GetNameSafe(Hit.GetComponent()) : TEXT("region boundary"),
                *GetActorLocation().ToCompactString());
            const auto P=GetActorLocation();Flight.position=starflight::FromUnreal({float(P.X),float(P.Y),float(P.Z)});
            Flight.velocity={};Throttle=0;
        }
        Accumulator-=starflight::Step;
    }
}
#if !UE_BUILD_SHIPPING
// Opt-in engine integration check. It drives real pawn movement and physics sweeps;
// keyboard/touch event delivery remains a separate hands-on acceptance check.
void AStarflightPawn::TickSmokeCheck() {
    ++SmokeFrame;
    auto Check=[this](bool Pass,const TCHAR* What) {
        SmokeFailed|=!Pass;
        UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_SMOKE %s: %s"),Pass?TEXT("PASS"):TEXT("FAIL"),What);
    };
    if(SmokeFrame==1) {
        FHitResult Ground;
        const auto P=GetActorLocation();
        FCollisionQueryParams Params;Params.AddIgnoredActor(this);
        const bool Hit=GetWorld()->LineTraceSingleByChannel(Ground,P,P-FVector(0,0,200000),ECC_Visibility,Params);
            Check(Region && Hit && FMath::Abs(Ground.ImpactPoint.Z/100-Region->Surface(Flight.position.x,Flight.position.z))<0.1,TEXT("visible terrain matches collision height"));
    }
    if(SmokeFrame<120) Throttle=0.5f;
    if(SmokeFrame==120) {
        Check(!Crashed && Region && Flight.position.z<Region->Arrival.z-10,TEXT("forward thrust moves pawn"));
        if(auto* PC=Cast<APlayerController>(GetController())) PC->ConsoleCommand(TEXT("HighResShot 1"));
    }
    if(SmokeFrame==150) { ToggleCamera();Check(Cockpit->IsActive() && !Chase->IsActive(),TEXT("cockpit camera")); }
    if(SmokeFrame==180) {
        ToggleCamera();Check(Chase->IsActive() && !Cockpit->IsActive(),TEXT("chase camera"));
        RestartFlight();Flight.pitch=-UE_PI/2;Throttle=1;
    }
    if(SmokeFrame==450) {
        Check(Crashed,TEXT("terrain impact stops flight"));
        RestartFlight();Check(!Crashed && Region && Flight.position.y==Region->Arrival.y && Throttle==0,TEXT("restart restores flight"));
        TogglePause();Check(UGameplayStatics::IsGamePaused(this),TEXT("pause"));
        TogglePause();Check(!UGameplayStatics::IsGamePaused(this),TEXT("resume"));
        const auto* Mode = GetWorld()->GetAuthGameMode<AStarflightGameMode>();
        UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_SMOKE %s RESULT: %s"),
            Mode ? WorldName(Mode->Planet) : TEXT("unknown"), SmokeFailed ? TEXT("FAIL") : TEXT("PASS"));
        if (!SmokeFailed && Mode && FParse::Param(FCommandLine::Get(),TEXT("StarflightTour")) &&
            Mode->Planet != EStarflightWorld::Coruscant) {
            SelectWorld(static_cast<EStarflightWorld>(static_cast<int32>(Mode->Planet)+1));
            return;
        }
        UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_SMOKE RESULT: %s"),SmokeFailed?TEXT("FAIL"):TEXT("PASS"));
        FPlatformMisc::RequestExitWithStatus(false,SmokeFailed?1:0);
    }
}
#endif
void AStarflightPawn::ToggleCamera() {
    CockpitActive=!CockpitActive;Cockpit->SetActive(CockpitActive);Chase->SetActive(!CockpitActive);
    Hull->SetVisibility(!CockpitActive);
}
void AStarflightPawn::TogglePause() {
    if(auto* PC=Cast<APlayerController>(GetController())) PC->SetPause(!UGameplayStatics::IsGamePaused(this));
}
void AStarflightPawn::SetupPlayerInputComponent(UInputComponent* Input) {
    Super::SetupPlayerInputComponent(Input);
    Input->BindAxis("Pitch",this,&AStarflightPawn::SetPitch);Input->BindAxis("Roll",this,&AStarflightPawn::SetRoll);
    Input->BindAxis("Yaw",this,&AStarflightPawn::SetYaw);Input->BindAxis("Throttle",this,&AStarflightPawn::SetThrottleAxis);
    auto BindWorld = [&](const FKey& Key, EStarflightWorld Planet) {
        FInputKeyBinding Binding(FInputChord(Key), IE_Pressed);
        Binding.KeyDelegate.GetDelegateForManualSet().BindWeakLambda(this,[this,Planet]{ SelectWorld(Planet); });
        Input->KeyBindings.Add(MoveTemp(Binding));
    };
    BindWorld(EKeys::One,EStarflightWorld::Hoth);
    BindWorld(EKeys::Two,EStarflightWorld::Tatooine);
    BindWorld(EKeys::Three,EStarflightWorld::Endor);
    BindWorld(EKeys::Four,EStarflightWorld::Coruscant);
    Input->BindKey(EKeys::M,IE_Pressed,this,&AStarflightPawn::ShowFlightPlanner);
    Input->BindAction("Camera",IE_Pressed,this,&AStarflightPawn::ToggleCamera);
    Input->BindAction("Restart",IE_Pressed,this,&AStarflightPawn::RestartFlight);
    auto& Pause=Input->BindAction("Pause",IE_Pressed,this,&AStarflightPawn::TogglePause);Pause.bExecuteWhenPaused=true;
    auto& Touch=Input->BindTouch(IE_Pressed,this,&AStarflightPawn::TouchBegin);Touch.bExecuteWhenPaused=true;
    Input->BindTouch(IE_Repeat,this,&AStarflightPawn::TouchMove);
    Input->BindTouch(IE_Released,this,&AStarflightPawn::TouchEnd);
}
void AStarflightPawn::SelectWorld(EStarflightWorld Planet) {
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    if (!Mode || Mode->Planet==Planet) return;
    UGameplayStatics::OpenLevel(this,FName(TEXT("/Engine/Maps/Entry")),true,
        FString(TEXT("World="))+WorldName(Planet));
}
void AStarflightPawn::ShowFlightPlanner() {
#if PLATFORM_MAC || PLATFORM_IOS
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    if (!Mode) return;
    TWeakObjectPtr<AStarflightPawn> WeakThis(this);
    OpenSwiftPlanner(static_cast<int32>(Mode->Planet),[WeakThis](int32 Index) {
        if (Index>=0 && Index<4) {
            if (auto* Pawn=WeakThis.Get()) Pawn->SelectWorld(static_cast<EStarflightWorld>(Index));
        }
    });
#endif
}

void AStarflightPawn::TouchBegin(ETouchIndex::Type Finger,FVector P) {
    auto* PC=Cast<APlayerController>(GetController());if(!PC) return;
    int32 W=0,H=0;PC->GetViewportSize(W,H);if(W<=0 || H<=0) return;
    if (P.Y<H*0.10) {
        SelectWorld(static_cast<EStarflightWorld>(FMath::Clamp(int32(P.X/W*4),0,3)));
        return;
    }
    if(P.Y>H*0.11 && P.Y<H*0.20 && P.X<W*0.20) { ShowFlightPlanner();return; }
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
