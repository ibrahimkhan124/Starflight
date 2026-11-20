#include "StarflightPrototype.h"
#include "Renderer.hpp"
#include "Fleet.hpp"
#include "WorldFeatures.hpp"
#include "StaticMeshResources.h"
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
    if (const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>()) ApplyShip(Mode->SelectedShip);
    RestartFlight();
#if !UE_BUILD_SHIPPING
    SmokeEnabled=FParse::Param(FCommandLine::Get(),TEXT("StarflightSmoke"));
    if (SmokeEnabled) {
        if (auto* PC=GetWorld()->GetFirstPlayerController()) DisableInput(PC);
    }
#endif
}
void AStarflightPawn::ApplyShip(int32 Index) {
    if (!FlightFleet().IsValidIndex(Index)) return;
    UStaticMesh* Mesh=LoadFleetShip(Index);
    if (!Mesh) return;
    ActiveShip=Index;
    Hull->SetStaticMesh(Mesh);
    const auto& Profile=ShipProfile(Index);
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    const bool City=Mode && Mode->Planet==EStarflightWorld::Coruscant;
    Collision->SetSphereRadius(100*(City ? Profile.CityRadius : Profile.BodyRadius));
    const auto Bounds=Mesh->GetBounds();
    if (Index>0) {
        // Blender's +Y nose imports as Unreal -Y. The mesh component already turns +90 degrees.
        // Match the authored span and length to the Swift aircraft dimensions.
        const FVector Scale(Profile.Span*50/Bounds.BoxExtent.X,Profile.Length*50/Bounds.BoxExtent.Y,
            Profile.Length*50/Bounds.BoxExtent.Y);
        Hull->SetRelativeScale3D(Scale);
        Hull->SetRelativeLocation(-Hull->GetRelativeRotation().RotateVector(Bounds.Origin*Scale));
    } else {
        Hull->SetRelativeScale3D(FVector::OneVector);
        Hull->SetRelativeLocation(FVector::ZeroVector);
    }
    Boom->TargetArmLength=100*(Index>0 ? FMath::Max(22.f,Profile.Length*1.7f) : 18.f);
    Boom->SocketOffset.Z=100*FMath::Max(5.f,Profile.Length*0.34f);
    Cockpit->SetRelativeLocation(FVector(Profile.Length*32,0,FMath::Max(90.f,Profile.BodyRadius*120)));
    UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_ACTIVE_SHIP: %s"),Profile.Name);
}

void AStarflightPawn::RestartFlight() {
    Flight=starflight::State{};
    if (Region) Flight.position=Region->Arrival;
    Throttle=Aerodynamic ? 0.65f : 0.f;
    if (Aerodynamic) {
        Flight.airspeed=ShipProfile(ActiveShip).Handling.cruise;
        Flight.velocity=Flight.Forward()*Flight.airspeed;
    }
    Crashed=false;RockImpact=false;RockWarning=false;WaterImpact=false;Accumulator=0;
    FlightTime=0;LowFlightPoints=0;
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
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    const auto World=Mode ? Mode->Planet : EStarflightWorld::Hoth;
    const float WindStrength=World==EStarflightWorld::Hoth ? 16.f : World==EStarflightWorld::Tatooine ? 12.f : 8.f;
    while(Accumulator>=starflight::Step && !Crashed) {
        starflight::Input Input;
        Input.pitch=FMath::Clamp(PitchAxis+float(TouchAxes.Y),-1.0f,1.0f);
        Input.roll=FMath::Clamp(RollAxis+float(TouchAxes.X),-1.0f,1.0f);
        Input.yaw=YawAxis;Input.throttle=Throttle;
        if (auto* PC=Cast<APlayerController>(GetController())) Input.boost=PC->IsInputKeyDown(EKeys::LeftShift);
        FlightTime+=starflight::Step;
        const auto Wind=starflight::WeatherWind(FlightTime,WindStrength);
        const auto Handling=ShipProfile(ActiveShip).Handling;
        if (Aerodynamic) starflight::AdvanceAtmosphere(Flight,Input,Wind,starflight::Step,Handling);
        else starflight::AdvanceSurface(Flight,Input,Wind,starflight::Step,Handling);
        FHitResult Hit;
        SetActorLocationAndRotation(ToUE(Flight.position),FRotator(FMath::RadiansToDegrees(Flight.pitch),FMath::RadiansToDegrees(Flight.heading),FMath::RadiansToDegrees(Flight.roll)),true,&Hit);
        // The physics sweep uses the exact visible triangles, not the smooth height recipe.
        Crashed=Hit.bBlockingHit || (Region && !Region->Contains(Flight.position));
        if (!Crashed && Region && Flight.airspeed>=45 && Throttle>0) {
            const float Clearance=Flight.position.y-Region->FlightSurface(Flight.position.x,Flight.position.z);
            if (Clearance>=8 && Clearance<60) LowFlightPoints+=(1-Clearance/60)*20*starflight::Step;
        }
        if(Crashed) {
            WaterImpact=Hit.GetComponent() && Hit.GetComponent()->GetFName()==TEXT("LakeSurface");
            UE_LOG(LogTemp, Display, TEXT("STARFLIGHT_IMPACT: %s at %s"),
                Hit.bBlockingHit ? *GetNameSafe(Hit.GetComponent()) : TEXT("region boundary"),
                *GetActorLocation().ToCompactString());
            const auto P=GetActorLocation();Flight.position=starflight::FromUnreal({float(P.X),float(P.Y),float(P.Z)});
            Flight.velocity={};Flight.airspeed=0;Throttle=0;
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
            Check(Region && Hit && FMath::Abs(Ground.ImpactPoint.Z/100-Region->FlightSurface(Flight.position.x,Flight.position.z))<0.1,TEXT("visible terrain matches collision height"));
    }
    if (SmokeFrame==1 && Region) {
        const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
        if (Mode) {
            for (const auto& Lake : WorldLakes(Mode->Planet)) {
                const FVector Above=ToUE({float(Lake.Centre.X),Lake.Level+80,float(Lake.Centre.Y)});
                FHitResult Surface;
                FCollisionQueryParams Params;
                Params.AddIgnoredActor(this);
                const bool Hit=GetWorld()->LineTraceSingleByChannel(Surface,Above,Above-FVector(0,0,12000),ECC_Visibility,Params);
                Check(Hit && Surface.GetComponent() && Surface.GetComponent()->GetFName()==TEXT("LakeSurface") &&
                      std::abs(Surface.ImpactPoint.Z/100-Lake.Level)<0.1,TEXT("lake surface matches collision"));
            }
        }
        if (FParse::Param(FCommandLine::Get(),TEXT("StarflightFleetCheck"))) {
            int32 Painted=0;
            for (int32 Index=1; Index<FlightFleet().Num(); ++Index) {
                const UStaticMesh* Mesh=LoadFleetShip(Index);
                const auto* Data=Mesh ? Mesh->GetRenderData() : nullptr;
                if (Data && !Data->LODResources.IsEmpty() && Data->LODResources[0].VertexBuffers.ColorVertexBuffer.GetNumVertices()>0) ++Painted;
            }
            Check(Painted==FlightFleet().Num()-1,TEXT("every Blender ship loads with its paint"));
            UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_FLEET_CHECK: %d painted Blender ships"),Painted);
        }
    }
    if(SmokeFrame<120) Throttle=0.5f;
    if(SmokeFrame==120) {
        Check(!Crashed && Region && Flight.position.z<Region->Arrival.z-10,TEXT("forward thrust moves pawn"));
        if (FParse::Param(FCommandLine::Get(),TEXT("StarflightScenicShots"))) VisitLake();
    }
    if (SmokeFrame==130) {
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
    Input->BindKey(EKeys::L,IE_Pressed,this,&AStarflightPawn::VisitLake);
    Input->BindKey(EKeys::V,IE_Pressed,this,&AStarflightPawn::ToggleAerodynamics);
    Input->BindKey(EKeys::LeftBracket,IE_Pressed,this,&AStarflightPawn::BrowseShip);
    Input->BindKey(EKeys::RightBracket,IE_Pressed,this,&AStarflightPawn::BrowseShip);
    Input->BindKey(EKeys::LeftMouseButton,IE_Pressed,this,&AStarflightPawn::ClickFlightHUD);
    Input->BindKey(EKeys::M,IE_Pressed,this,&AStarflightPawn::ShowFlightPlanner);
    Input->BindAction("Camera",IE_Pressed,this,&AStarflightPawn::ToggleCamera);
    Input->BindAction("Restart",IE_Pressed,this,&AStarflightPawn::RestartFlight);
    auto& Pause=Input->BindAction("Pause",IE_Pressed,this,&AStarflightPawn::TogglePause);Pause.bExecuteWhenPaused=true;
    auto& Touch=Input->BindTouch(IE_Pressed,this,&AStarflightPawn::TouchBegin);Touch.bExecuteWhenPaused=true;
    Input->BindTouch(IE_Repeat,this,&AStarflightPawn::TouchMove);
    Input->BindTouch(IE_Released,this,&AStarflightPawn::TouchEnd);
}
void AStarflightPawn::BrowseShip(FKey Key) {
    const int32 Count=FlightFleet().Num();
    ApplyShip((ActiveShip+Count+(Key==EKeys::RightBracket ? 1 : -1))%Count);
}

void AStarflightPawn::ToggleAerodynamics() {
    Aerodynamic=!Aerodynamic;
    if (Aerodynamic && Flight.airspeed < ShipProfile(ActiveShip).Handling.cruise*0.55f) {
        Flight.airspeed=ShipProfile(ActiveShip).Handling.cruise*0.65f;
        Flight.velocity=Flight.Forward()*Flight.airspeed;
        Throttle=0.65f;
    }
}

void AStarflightPawn::VisitLake() {
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    if (!Mode || !Region) return;
    const auto Lakes=WorldLakes(Mode->Planet);
    if (Lakes.IsEmpty()) return;
    const auto& Lake=Lakes[NextLake++%Lakes.Num()];
    const bool Frozen=Mode->Planet==EStarflightWorld::Hoth;
    const float X=Lake.Centre.X+Lake.Radii.X*(Frozen ? 0.22f : -0.15f);
    const float Z=Lake.Centre.Y+Lake.Radii.Y*(Frozen ? 0.77f : 0.71f);
    Aerodynamic=false;
    if (Crashed) RestartFlight();
    Flight=starflight::State{};
    Flight.position={X,Region->FlightSurface(X,Z)+(Frozen ? 65.f : 43.f),Z};
    Flight.heading=Frozen ? 0.19f : 0.12f;
    Flight.pitch=-0.04f;
    Throttle=0;
    RockWarning=false;
    Accumulator=0;
    SetActorLocationAndRotation(ToUE(Flight.position),
        FRotator(FMath::RadiansToDegrees(Flight.pitch),FMath::RadiansToDegrees(Flight.heading),0),
        false,nullptr,ETeleportType::TeleportPhysics);
}

void AStarflightPawn::ClickFlightHUD() {
#if PLATFORM_MAC
    auto* PC=Cast<APlayerController>(GetController());
    if (!PC) return;
    int32 Width=0,Height=0;
    float X=0,Y=0;
    PC->GetViewportSize(Width,Height);
    if (Width<=0 || !PC->GetMousePosition(X,Y)) return;
    if (Y>=7 && Y<=39) SelectWorld(static_cast<EStarflightWorld>(FMath::Clamp(int32(X/Width*4),0,3)));
#endif
}

void AStarflightPawn::SelectWorld(EStarflightWorld Planet,int32 Ship) {
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    const int32 Choice=FlightFleet().IsValidIndex(Ship) ? Ship : ActiveShip;
    if (!Mode || Mode->Planet==Planet) {
        if (Choice!=ActiveShip) ApplyShip(Choice);
        return;
    }
    UGameplayStatics::OpenLevel(this,FName(TEXT("/Engine/Maps/Entry")),true,
        FString::Printf(TEXT("World=%s?Ship=%s"),WorldName(Planet),ShipProfile(Choice).Id));
}

void AStarflightPawn::ShowFlightPlanner() {
#if PLATFORM_MAC || PLATFORM_IOS
    const auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    if (!Mode) return;
    TArray<FString> Names;
    for (const auto& Ship : FlightFleet()) Names.Add(Ship.Name);
    TWeakObjectPtr<AStarflightPawn> WeakThis(this);
    OpenSwiftPlanner(static_cast<int32>(Mode->Planet),Names,ActiveShip,[WeakThis](int32 Index,int32 Ship) {
        if (Index>=0 && Index<4) {
            if (auto* Pawn=WeakThis.Get()) Pawn->SelectWorld(static_cast<EStarflightWorld>(Index),Ship);
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
