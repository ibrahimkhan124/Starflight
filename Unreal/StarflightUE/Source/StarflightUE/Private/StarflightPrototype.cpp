#include "StarflightPrototype.h"
#include "GraphicsEngine/Renderer.hpp"
#include "GraphicsEngine/PlanetWeather.h"
#include "GraphicsEngine/CityTraffic.h"
#include "GraphicsEngine/Fleet.hpp"
#include "Engine/Canvas.h"
#include "Engine/GameViewportClient.h"
#include "Engine/LocalPlayer.h"
#include "GameFramework/PlayerController.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"

void AStarflightHUD::DrawHUD() {
    Super::DrawHUD();
    auto* Pawn=Cast<AStarflightPawn>(GetOwningPawn());
    auto* Mode=GetWorld()->GetAuthGameMode<AStarflightGameMode>();
    if (!Pawn || !Mode || !Canvas) return;
    const float W=Canvas->ClipX, H=Canvas->ClipY;
    const FLinearColor Panel(0.012,0.028,0.059,0.86);
    const FLinearColor Cyan(0.30,0.88,1.0);
    for (int32 Index=0; Index<4; ++Index) {
        const auto Planet=static_cast<EStarflightWorld>(Index);
        const bool Active=Planet==Mode->Planet;
        const float Left=W*Index/4+6;
        DrawRect(Panel,Left,7,W/4-12,32);
        if (Active) DrawRect(Cyan,Left,37,W/4-12,2);
        DrawText(FString::Printf(TEXT("%d   %s"),Index+1,WorldName(Planet)),Active ? Cyan : FLinearColor::White,Left+12,15);
    }
    DrawRect(Panel,W-302,49,290,30);
    DrawText(FString::Printf(TEXT("%s  ·  %s"),ShipProfile(Pawn->ActiveShip).Name,
        Pawn->Aerodynamic ? TEXT("LIFT") : TEXT("HOVER")),Cyan,W-292,57);
    if (Pawn->Region) {
        const float AGL=Pawn->Flight.position.y-Pawn->Region->FlightSurface(Pawn->Flight.position.x,Pawn->Flight.position.z);
        DrawRect(Panel,12,49,330,30);
        DrawText(FString::Printf(TEXT("%.0f kt    ALT %.0f m    AGL %.0f m    THR %.0f%%"),
            Pawn->Flight.airspeed*1.94384f,Pawn->Flight.position.y,AGL,Pawn->Throttle*100), FLinearColor::White,23,57);
    }
#if PLATFORM_IOS
    DrawText(TEXT("PLANNER"),Cyan,26,H*0.15f);
    DrawText(TEXT("STEER"),Cyan,26,H*0.77f);
    DrawRect(Panel,W*0.90f,H*0.25f,20,H*0.60f);
    DrawRect(Cyan,W*0.90f-5,H*(0.25f+(1-Pawn->Throttle)*0.3f),30,8);
    DrawText(TEXT("PAUSE"),FLinearColor::White,W*0.60f,H*0.15f);
    DrawText(TEXT("CAMERA"),FLinearColor::White,W*0.78f,H*0.15f);
#else
    DrawRect(Panel,12,H-40,FMath::Min(730.f,W-24),28);
    DrawText(TEXT("W/S pitch   A/D bank   Q/E yaw   R/F throttle   C camera   M planner   [ ] ships   V lift   L lakes"),FLinearColor::White,23,H-33);
#endif
    if (Pawn->Flight.stalled && !Pawn->Crashed)
        DrawText(TEXT("STALL  ·  LOWER NOSE AND ADD POWER"),FLinearColor(1,0.72,0.31),W*0.35f,H*0.14f);
    if (Pawn->LowFlightPoints>=1)
        DrawText(FString::Printf(TEXT("LOW FLIGHT  %d"),int32(Pawn->LowFlightPoints)),Cyan,23,87);
    if (Pawn->RockWarning && !Pawn->Crashed) {
        DrawRect(Panel,W*0.34f,H*0.13f,W*0.32f,28);
        DrawText(TEXT("ROCKSLIDE NEARBY"),FLinearColor(1,0.76,0.38),W*0.37f,H*0.14f);
    }
    if (Pawn->Crashed) {
        DrawRect(Panel,W*0.26f,H*0.43f,W*0.48f,42);
        DrawText(Pawn->WaterImpact ? TEXT("LAKE IMPACT   ·   Tap or press Enter to restart") : Pawn->RockImpact ? TEXT("ROCK IMPACT   ·   Tap or press Enter to restart") :
                 TEXT("FLIGHT INTERRUPTED   ·   Tap or press Enter to restart"),FLinearColor::White,W*0.28f,H*0.45f);
    }
}

AStarflightGameMode::AStarflightGameMode() : Planet(EStarflightWorld::Hoth) {
    bPauseable=true;
    DefaultPawnClass=AStarflightPawn::StaticClass();
    HUDClass=AStarflightHUD::StaticClass();
}

void AStarflightGameMode::InitGame(const FString& MapName,const FString& Options,FString& Error) {
    Super::InitGame(MapName,Options,Error);
    FString Ship=UGameplayStatics::ParseOption(Options,TEXT("Ship"));
    if (Ship.IsEmpty()) FParse::Value(FCommandLine::Get(),TEXT("StarflightShip="),Ship);
    SelectedShip=FleetIndex(Ship);
    FString Selection=UGameplayStatics::ParseOption(Options,TEXT("World"));
    if (Selection.IsEmpty()) FParse::Value(FCommandLine::Get(),TEXT("StarflightWorld="),Selection);
    for (int32 Index=0; Index<4; ++Index) {
        const auto Choice=static_cast<EStarflightWorld>(Index);
        if (Selection.Equals(WorldName(Choice),ESearchCase::IgnoreCase)) Planet=Choice;
    }
}

void AStarflightGameMode::StartPlay() {
    auto* Region = GetWorld()->SpawnActor<AStarflightRegion>();
    auto* Haze = BuildSky(*GetWorld(),Planet);
    if (Region && Region->Prepare(Planet) && Haze) {
        if (auto* Weather=GetWorld()->SpawnActor<AStarflightWeather>()) Weather->Configure(*Region,Planet,*Haze);
    }
    if (Planet==EStarflightWorld::Coruscant) GetWorld()->SpawnActor<AStarflightCityTraffic>();
    Super::StartPlay();
#if PLATFORM_MAC
    if (auto* PC=GetWorld()->GetFirstPlayerController()) {
        PC->bShowMouseCursor=true;
        FInputModeGameAndUI Mode;
        Mode.SetHideCursorDuringCapture(false);
        Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
        PC->SetInputMode(Mode);
        if (auto* Local=PC->GetLocalPlayer(); Local && Local->ViewportClient)
            Local->ViewportClient->SetMouseCaptureMode(EMouseCaptureMode::NoCapture);
    }
#endif
}
