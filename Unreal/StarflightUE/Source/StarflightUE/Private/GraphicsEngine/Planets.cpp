#include "StarflightPrototype.h"
#include "Renderer.hpp"
#include "WorldFeatures.hpp"
#include "Algo/AnyOf.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInterface.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "ProceduralMeshComponent.h"
#include "Serialization/MemoryReader.h"

namespace {
struct FPlanetObstacle {
    starflight::Vec3 Position;
    starflight::Vec3 Size;
    float Yaw = 0;
    uint32 Style = 0;
};
struct FPlanetData {
    TArray<float> Heights;
    TArray<FPlanetObstacle> Obstacles;
    starflight::Vec3 Arrival;
    float Extent = 0;
    uint32 Cells = 0;
};

bool ReadPlanet(EStarflightWorld Planet, FPlanetData& Data) {
    const FString Name = FString(WorldName(Planet)).ToLower() + TEXT(".sfworld");
    TArray<uint8> Bytes;
    if (!FFileHelper::LoadFileToArray(Bytes, *(FPaths::ProjectContentDir() / TEXT("Starflight/Worlds") / Name))) {
        return false;
    }
    if (Bytes.Num() < 28 || FMemory::Memcmp(Bytes.GetData(), "SFW1", 4) != 0) return false;
    FMemoryReader Reader(Bytes);
    Reader.Seek(4);
    uint32 ObstacleCount = 0;
    Reader << Data.Cells << ObstacleCount << Data.Extent;
    Reader << Data.Arrival.x << Data.Arrival.y << Data.Arrival.z;
    if (Data.Cells < 1 || Data.Cells > 320 || ObstacleCount > 10000 || Data.Extent != 12000) return false;
    const int32 VertexCount = FMath::Square(Data.Cells + 1);
    if (Reader.TotalSize() != 28ll + VertexCount * 4ll + ObstacleCount * 32ll) return false;
    Data.Heights.SetNumUninitialized(VertexCount);
    for (float& Height : Data.Heights) {
        Reader << Height;
        if (!FMath::IsFinite(Height)) return false;
    }
    Data.Obstacles.SetNum(ObstacleCount);
    for (auto& Obstacle : Data.Obstacles) {
        auto& P = Obstacle.Position;
        auto& S = Obstacle.Size;
        Reader << P.x << P.y << P.z << S.x << S.y << S.z << Obstacle.Yaw << Obstacle.Style;
    }
    return !Reader.IsError();
}

FLinearColor TerrainColor(EStarflightWorld Planet, float Height, float Slope, float X, float Z) {
    const float Var = 0.5f + 0.5f * FMath::Sin(X * 0.0021f + FMath::Cos(Z * 0.0016f));
    switch (Planet) {
        case EStarflightWorld::Hoth: {
            const auto Ice = FMath::Lerp(FLinearColor(0.14,0.34,0.50), FLinearColor(0.47,0.70,0.80), Var);
            const float Snow = FMath::Clamp(0.71f + Height / 2700 - Slope * 1.75f, 0.f, 1.f);
            return FMath::Lerp(Ice, FLinearColor(0.83,0.91,0.96), Snow);
        }
        case EStarflightWorld::Tatooine: {
            const float Band = 0.5f + 0.5f * FMath::Sin(Height * 0.035f + Var * 2);
            const auto Sand = FMath::Lerp(FLinearColor(0.51,0.30,0.14), FLinearColor(0.76,0.54,0.28), Var);
            const auto Rock = FMath::Lerp(FLinearColor(0.22,0.066,0.027), FLinearColor(0.47,0.18,0.08), Band);
            return FMath::Lerp(Sand, Rock, FMath::Clamp(Slope * 2.8f, 0.f, 1.f));
        }
        case EStarflightWorld::Endor:
            return FMath::Lerp(FMath::Lerp(FLinearColor(0.032,0.065,0.026), FLinearColor(0.086,0.15,0.045), Var),
                FLinearColor(0.19,0.173,0.109), FMath::Clamp(Slope * 2.2f, 0.f, 1.f));
        case EStarflightWorld::Coruscant:
            return FLinearColor(0.022,0.034,0.058);
    }
    return FLinearColor::White;
}
}

AStarflightRegion::AStarflightRegion() {
    TerrainMesh = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("PlanetSurface"));
    SetRootComponent(TerrainMesh);
    TerrainMesh->SetMobility(EComponentMobility::Static);
    TerrainMesh->bUseAsyncCooking = false;
    TerrainMesh->bUseComplexAsSimpleCollision = true;
    TerrainMesh->SetCollisionProfileName(TEXT("BlockAll"));
}

bool AStarflightRegion::Prepare(EStarflightWorld Planet) {
    FPlanetData Data;
    if (!ReadPlanet(Planet, Data)) {
        UE_LOG(LogTemp, Error, TEXT("Could not load Starflight world %s"), WorldName(Planet));
        return false;
    }
    Extent = Data.Extent;
    Cells = Data.Cells;
    Arrival = Data.Arrival;
    Heights = MoveTemp(Data.Heights);
    World = Planet;
    const int32 Stride = Cells + 1;
    const float Step = 2 * Extent / Cells;
    const auto Lakes=WorldLakes(Planet);
    // Apply the basin cuts once before normals, scenery heights and collision are built.
    for (int32 Row=0; Row<=Cells; ++Row) {
        for (int32 Column=0; Column<=Cells; ++Column) {
            const float X=Column*Step-Extent, Z=Row*Step-Extent;
            float& Height=Heights[Row*Stride+Column];
            for (const auto& Lake : Lakes) {
                if (FMath::Abs(X-Lake.Centre.X)<Lake.Radii.X*1.55 &&
                    FMath::Abs(Z-Lake.Centre.Y)<Lake.Radii.Y*1.55) Height=Lake.Cut(Height,X,Z);
            }
        }
    }
    TArray<FVector> Vertices, Normals;
    TArray<FVector2D> UVs;
    TArray<FLinearColor> Colors;
    TArray<int32> Triangles;
    TArray<FProcMeshTangent> Tangents;
    Vertices.Reserve(Heights.Num());
    Normals.Reserve(Heights.Num());
    Colors.Reserve(Heights.Num());
    Triangles.Reserve(Cells * Cells * 6);
    auto Height = [&](int32 X, int32 Z) {
        return Heights[FMath::Clamp(Z,0,Cells) * Stride + FMath::Clamp(X,0,Cells)];
    };
    for (int32 Z = 0; Z <= Cells; ++Z) {
        for (int32 X = 0; X <= Cells; ++X) {
            const float PX = -Extent + Step * X, PZ = -Extent + Step * Z;
            const float H = Height(X,Z);
            const FVector N = ToUE({Height(X-1,Z)-Height(X+1,Z), 2 * Step, Height(X,Z-1)-Height(X,Z+1)}).GetSafeNormal();
            Vertices.Add(ToUE({PX,H,PZ}));
            Normals.Add(N);
            Colors.Add(TerrainColor(Planet,H,1 - N.Z,PX,PZ));
            if (X == Cells || Z == Cells) continue;
            const int32 A = Z*Stride+X, B = A+1, C = A+Stride, D = C+1;
            Triangles.Append({A,C,D,A,D,B});
        }
    }
    TerrainMesh->CreateMeshSection_LinearColor(0,Vertices,Triangles,Normals,UVs,Colors,Tangents,true);
    TerrainMesh->SetMaterial(0,ScenicMaterial(TEXT("M_PlanetTerrain")));

    auto Instances = [&](const TCHAR* Name, const TCHAR* Shape, const TCHAR* Paint, bool Solid) {
        auto* Group = NewObject<UInstancedStaticMeshComponent>(this, FName(Name));
        Group->SetupAttachment(TerrainMesh);
        Group->SetMobility(EComponentMobility::Static);
        auto* Mesh = LoadObject<UStaticMesh>(nullptr, Shape);
        if (!Mesh) Mesh = LoadObject<UStaticMesh>(nullptr,TEXT("/Engine/BasicShapes/Cube.Cube"));
        Group->SetStaticMesh(Mesh);
        Group->SetMaterial(0, ScenicMaterial(Paint));
        Group->SetCollisionProfileName(Solid ? TEXT("BlockAll") : TEXT("NoCollision"));
        AddInstanceComponent(Group);
        return Group;
    };
    const TCHAR* Cube = TEXT("/Engine/BasicShapes/Cube.Cube");
    const TCHAR* Cylinder = TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
    const TCHAR* Glacier = TEXT("/Game/Starflight/Scenery/SM_GlacierRock.SM_GlacierRock");
    const TCHAR* Mesa = TEXT("/Game/Starflight/Scenery/SM_SandstoneMesa.SM_SandstoneMesa");
    const TCHAR* Foliage = TEXT("/Game/Starflight/Scenery/SM_ForestCrown.SM_ForestCrown");
    auto Add = [](UInstancedStaticMeshComponent* Group, starflight::Vec3 P, starflight::Vec3 S, float Yaw = 0) {
        const FBoxSphereBounds Bounds = Group->GetStaticMesh()->GetBounds();
        const FVector Size(S.z,S.x,S.y);
        const FVector Scale = Size * 100 / (Bounds.BoxExtent * 2);
        const FQuat Rotation(FVector::UpVector,Yaw);
        Group->AddInstance(FTransform(Rotation,ToUE(P)-Rotation.RotateVector(Bounds.Origin*Scale),Scale));
    };
    UInstancedStaticMeshComponent* Solid = nullptr;
    UInstancedStaticMeshComponent* Crown = nullptr;
    UInstancedStaticMeshComponent* Young = nullptr;
    switch (Planet) {
        case EStarflightWorld::Coruscant:
            Solid = Instances(TEXT("CityTowers"),Cube,TEXT("M_CityFacade"),true); break;
        case EStarflightWorld::Hoth:
            Solid = Instances(TEXT("GlacierSpurs"),Glacier,TEXT("M_Ice"),true); break;
        case EStarflightWorld::Tatooine:
            Solid = Instances(TEXT("SandstoneSpurs"),Mesa,TEXT("M_Sandstone"),true); break;
        case EStarflightWorld::Endor:
            Solid = Instances(TEXT("ForestTrunks"),Cylinder,TEXT("M_Bark"),true);
            Crown = Instances(TEXT("OldGrowthCanopy"),Foliage,TEXT("M_CanopyGreen"),true);
            Young = Instances(TEXT("Understory"),Foliage,TEXT("M_CanopyPine"),false); break;
    }
    auto* Beacons = Instances(TEXT("Outposts"),Cube,TEXT("M_Titanium"),true);
    for (const auto& Obstacle : Data.Obstacles) {
        auto P = Obstacle.Position;
        auto S = Obstacle.Size;
        if (Algo::AnyOf(Lakes,[&](const FLakeBasin& Lake) {
            return Lake.Distance(P.x,P.z)<(Crown ? 1.49f : 1.05f);
        })) continue;
        if (Obstacle.Style == 3) {
            Add(Beacons,P,S);
        } else if (Crown) {
            const float Base = P.y - S.y / 2;
            Add(Solid,{P.x,Base + S.y * 0.38f,P.z},{S.x * 0.28f,S.y * 0.76f,S.z * 0.28f});
            const float Spin = 2*FMath::Sin(P.x*0.21f+P.z*0.13f);
            Add(Crown,{P.x,Base + S.y * 0.76f,P.z},{S.x * 2.05f,S.y * 0.39f,S.z * 1.65f},Spin);
            Add(Crown,{P.x-S.x*0.38f,Base + S.y * 0.89f,P.z+S.z*0.24f},{S.x*1.42f,S.y*0.28f,S.z*1.38f},-Spin);
            Add(Crown,{P.x + S.x*0.58f,Base + S.y * 0.67f,P.z - S.z*0.38f},{S.x*1.18f,S.y*0.32f,S.z*1.2f});
        } else if (Planet!=EStarflightWorld::Coruscant) {
            const float Base = P.y-S.y/2;
            const float Ground = Surface(P.x,P.z);
            P.y = (Ground+Base)/2 + S.y*0.24f;
            S.y *= 0.92f;
            S.x *= 1.13f;
            const float Spin = 2*FMath::Sin(P.x*0.21f+P.z*0.13f);
            Add(Solid,P,S,Spin);
            Add(Solid,{P.x+S.x*0.33f,P.y-S.y*0.25f,P.z-S.z*0.22f},
                {S.x*0.62f,S.y*0.68f,S.z*0.75f},-Spin);
        } else {
            Add(Solid,P,S,-Obstacle.Yaw);
            if (Obstacle.Style < 3 && S.y > 315) {
                const float Roof = P.y+S.y/2;
                Add(Solid,{P.x,Roof+S.y*0.047f,P.z},{S.x*0.72f,S.y*0.11f,S.z*0.77f});
                if (Obstacle.Style == 1) {
                    Add(Solid,{P.x-S.x*0.2f,Roof+S.y*0.14f,P.z},{S.x*0.10f,S.y*0.16f,S.z*0.1f});
                }
            }
        }
    }

    if (Young) {
        FRandomStream Random(20887);
        for (int32 Index = 0; Index < 2300; ++Index) {
            const float X = Random.FRandRange(-Extent,Extent), Z = Random.FRandRange(-Extent,Extent);
            const float H = Random.FRandRange(45,180);
            if (Algo::AnyOf(Lakes,[&](const FLakeBasin& Lake) {
                return Lake.Distance(X,Z)<1.46f;
            })) continue;
            Add(Young,{X,Surface(X,Z)+H*0.43f,Z},{H*0.6f,H,H*0.6f});
        }
        Crown->RegisterComponent();
        Young->RegisterComponent();
    }
    Solid->RegisterComponent();
    Beacons->RegisterComponent();
    AddLakeFeatures(*this,Planet,Vertices,Triangles);
    if (Planet==EStarflightWorld::Coruscant) AddCityRoads(*this);
    UE_LOG(LogTemp, Display, TEXT("STARFLIGHT_WORLD %s: %d vertices, %d scenery records"), WorldName(Planet), Heights.Num(), Data.Obstacles.Num());
    return true;
}

float AStarflightRegion::Surface(float X, float Z) const {
    if (Cells == 0) return 0;
    const float GX = FMath::Clamp((X + Extent)*Cells/(2*Extent),0.f,float(Cells));
    const float GZ = FMath::Clamp((Z + Extent)*Cells/(2*Extent),0.f,float(Cells));
    const int32 Col = FMath::Min(FMath::FloorToInt(GX),Cells-1), Row = FMath::Min(FMath::FloorToInt(GZ),Cells-1);
    const float U = GX-Col, V = GZ-Row;
    const int32 A = Row*(Cells+1)+Col, B = A+1, C = A+Cells+1, D = C+1;
    if (V >= U) return Heights[A]*(1-V) + Heights[C]*(V-U) + Heights[D]*U;
    return Heights[A]*(1-U) + Heights[B]*(U-V) + Heights[D]*V;
}

float AStarflightRegion::FlightSurface(float X,float Z) const {
    const float Ground=Surface(X,Z);
    for (const auto& Lake : WorldLakes(World)) {
        if (Ground<Lake.Level && Lake.Distance(X,Z)<1.09f) return Lake.Level;
    }
    return Ground;
}
