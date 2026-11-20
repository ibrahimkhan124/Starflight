#include "WorldFeatures.hpp"
#include "StarflightPrototype.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInterface.h"
#include "ProceduralMeshComponent.h"

namespace {
const FLakeBasin EndorLakes[] = {
    {{120,6990},{720,1070},123,36},
    {{-1700,3080},{950,710},165,46},
    {{980,250},{660,1100},240,49},
};
const FLakeBasin HothLakes[] = {
    {{345,6910},{790,1040},164,33},
    {{-430,2300},{960,780},172,42},
};

float Smooth(float A, float B, float X) {
    const float T=FMath::Clamp((X-A)/(B-A),0.f,1.f);
    return T*T*(3-2*T);
}

UProceduralMeshComponent* SurfaceMesh(AStarflightRegion& Region,const TCHAR* Name,
    const TCHAR* Material,bool Solid) {
    auto* Mesh=NewObject<UProceduralMeshComponent>(&Region,FName(Name));
    Region.AddInstanceComponent(Mesh);
    Mesh->SetupAttachment(Region.GetRootComponent());
    Mesh->SetMobility(EComponentMobility::Static);
    Mesh->bUseComplexAsSimpleCollision=Solid;
    Mesh->SetCollisionProfileName(Solid ? TEXT("BlockAll") : TEXT("NoCollision"));
    Mesh->SetMaterial(0,ScenicMaterial(Material));
    return Mesh;
}

struct FSurfaceDraft {
    TArray<FVector> Points;
    TArray<FVector> Normals;
    TArray<FLinearColor> Colors;
    TArray<int32> Indices;

    void Add(const FVector& Point,const FLinearColor& Color) {
        Points.Add(Point);
        Normals.Add(FVector::UpVector);
        Colors.Add(Color);
    }

    void Plate(float MinX,float MaxX,float MinZ,float MaxZ,float Elevation) {
        int32 Start=Points.Num();
        Add(ToUE({MinX,Elevation,MinZ}),FLinearColor::White);
        Add(ToUE({MinX,Elevation,MaxZ}),FLinearColor::White);
        Add(ToUE({MaxX,Elevation,MaxZ}),FLinearColor::White);
        Add(ToUE({MaxX,Elevation,MinZ}),FLinearColor::White);
        Indices.Append({Start,Start+1,Start+2,Start,Start+2,Start+3});
    }

    void Publish(UProceduralMeshComponent& Mesh,bool Solid) {
        Mesh.CreateMeshSection_LinearColor(0,Points,Indices,Normals,{},Colors,{},Solid);
        Mesh.RegisterComponent();
    }
};

UInstancedStaticMeshComponent* Instances(AStarflightRegion& Owner,const TCHAR* Name,
    const TCHAR* Shape,const TCHAR* Material,bool Solid) {
    auto* Mesh=NewObject<UInstancedStaticMeshComponent>(&Owner,FName(Name));
    Owner.AddInstanceComponent(Mesh);
    Mesh->SetupAttachment(Owner.GetRootComponent());
    Mesh->SetMobility(EComponentMobility::Static);
    Mesh->SetCollisionProfileName(Solid ? TEXT("BlockAll") : TEXT("NoCollision"));
    Mesh->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,Shape));
    Mesh->SetMaterial(0,ScenicMaterial(Material));
    return Mesh;
}

void Place(UInstancedStaticMeshComponent& Mesh,starflight::Vec3 Position,
    starflight::Vec3 Lengths,const FRotator& Rotation={}) {
    const auto Bounds=Mesh.GetStaticMesh()->GetBounds();
    const FVector Scale=100*FVector(Lengths.z,Lengths.x,Lengths.y)/(2*Bounds.BoxExtent);
    Mesh.AddInstance(FTransform(Rotation,ToUE(Position)-Rotation.RotateVector(Bounds.Origin*Scale),Scale));
}

void PlantBanks(AStarflightRegion& Region,TConstArrayView<FLakeBasin> Lakes,FRandomStream& Random) {
    auto* Bark=Instances(Region,TEXT("DetailedShoreTrunks"),
        TEXT("/Game/Starflight/Scenery/SM_ShoreBark.SM_ShoreBark"),TEXT("M_ShoreBark"),true);
    auto* Leaves=Instances(Region,TEXT("DetailedShoreFoliage"),
        TEXT("/Game/Starflight/Scenery/SM_ShoreLeaves.SM_ShoreLeaves"),TEXT("M_ShoreLeaves"),false);
    if (!Bark->GetStaticMesh() || !Leaves->GetStaticMesh()) return;
    for (const auto& Lake : Lakes) {
        for (int32 I=0; I<104; ++I) {
            const float Theta=I*(2*UE_PI/104.f)+Random.FRandRange(-0.04,0.04);
            const float Distance=Random.FRandRange(1.03,1.52);
            const FVector2D P=Lake.Centre+Lake.Radii*FVector2D(FMath::Cos(Theta),FMath::Sin(Theta))*Distance;
            const float Floor=Region.Surface(P.X,P.Y);
            if (Floor<Lake.Level+1 || (FMath::Abs(P.X-Lake.Centre.X)<145 && P.Y>Lake.Centre.Y)) continue;
            const float Size=Random.FRandRange(4.4,11.4);
            const FTransform Transform(FRotator(0,Random.FRandRange(-180,180),0),
                ToUE({float(P.X),Floor,float(P.Y)}),FVector(Size));
            Bark->AddInstance(Transform);
            Leaves->AddInstance(Transform);
        }
    }
    Bark->RegisterComponent();
    Leaves->RegisterComponent();
}

void Shoreline(AStarflightRegion& Region, TConstArrayView<FLakeBasin> Lakes,bool Frozen) {
    constexpr auto Rock=TEXT("/Game/Starflight/Scenery/SM_GlacierRock.SM_GlacierRock");
    constexpr auto Box=TEXT("/Engine/BasicShapes/Cube.Cube");
    auto* Stones=Instances(Region,TEXT("ShoreStones"),Rock,
        Frozen ? TEXT("M_Ice") : TEXT("M_ShoreStone"),false);
    FRandomStream Random(Frozen ? 3421 : 8878);
    for (const auto& Lake : Lakes) {
        for (int32 I=0; I<104; ++I) {
            const float Angle=Random.FRandRange(0,2*UE_PI);
            const float Radius=Random.FRandRange(0.84,1.14);
            const FVector2D P=Lake.Centre+Lake.Radii*FVector2D(FMath::Cos(Angle),FMath::Sin(Angle))*Radius;
            const float Base=FMath::Max(Region.Surface(P.X,P.Y),Lake.Level);
            const float Size=Random.FRandRange(5,29);
            Place(*Stones,{float(P.X),Base+Size*0.11f,float(P.Y)},
                {Size,Size*0.66f,Size*Random.FRandRange(0.7,1.7)},
                FRotator(Random.FRandRange(-15,15),Random.FRandRange(-180,180),Random.FRandRange(-18,18)));
        }
    }
    Stones->RegisterComponent();
    if (!Frozen) {
        PlantBanks(Region,Lakes,Random);
        return;
    }

    auto* Metal=Instances(Region,TEXT("WalkerWreckage"),Box,TEXT("M_Wreck"),true);
    auto* Rime=Instances(Region,TEXT("WreckageIce"),Rock,TEXT("M_WreckFrost"),false);
    for (int32 I=0; I<Lakes.Num(); ++I) {
        const auto& Lake=Lakes[I];
        const float X=Lake.Centre.X+Lake.Radii.X*0.34f;
        const float Z=Lake.Centre.Y+Lake.Radii.Y*0.25f;
        const float Y=Lake.Level;
        // Buried armoured hull and separated jointed supports silhouetted above the ice.
        Place(*Metal,{X,Y+16,Z},{35,35,64},FRotator(-12,24,20));
        Place(*Metal,{X+7,Y+13,Z-39},{23,20,32},FRotator(14,21,-10));
        for (float Side : {-1.f,1.f}) {
            for (float End : {-1.f,1.f}) {
                const float PX=X+Side*32, PZ=Z+End*21;
                Place(*Metal,{PX,Y+9,PZ},{8,8,31},FRotator(11,41+End*47,20*Side));
                Place(*Metal,{PX+Side*15,Y+5,PZ+End*16},{8,12,26},FRotator(-21,24+End*40,4));
                Place(*Metal,{PX+Side*27,Y+3,PZ+End*23},{22,8,18},FRotator(0,59,8));
                Place(*Rime,{PX+Side*13,Y+1,PZ+End*17},{29,17,39},FRotator(0,41,0));
            }
        }
        Place(*Rime,{X,Y+14,Z+14},{44,25,43},FRotator(0,24,0));
    }
    Metal->RegisterComponent();
    Rime->RegisterComponent();
}
}

float FLakeBasin::Distance(float X,float Z) const {
    const FVector2D XY=(FVector2D(X,Z)-Centre)/Radii;
    const float Angle=FMath::Atan2(XY.Y,XY.X);
    const float Shore=1.f+0.09f*FMath::Sin(3*Angle+0.7f)+0.055f*FMath::Cos(7*Angle);
    return XY.Length()/Shore;
}

float FLakeBasin::Cut(float Height,float X,float Z) const {
    const float Q=Distance(X,Z);
    if (Q>=1.32f) return Height;
    const float Bowl=Level+Depth*(FMath::Clamp(Q*Q,0.f,1.55f)-0.82f);
    return FMath::Lerp(Bowl,Height,Smooth(1.00f,1.32f,Q));
}

TConstArrayView<FLakeBasin> WorldLakes(EStarflightWorld World) {
    if (World==EStarflightWorld::Endor) return MakeArrayView(EndorLakes);
    if (World==EStarflightWorld::Hoth) return MakeArrayView(HothLakes);
    return {};
}

void AddLakeFeatures(AStarflightRegion& Region,EStarflightWorld World,
    const TArray<FVector>& Terrain,const TArray<int32>& Triangles) {
    const auto Lakes=WorldLakes(World);
    if (Lakes.IsEmpty()) return;
    const bool Frozen=World==EStarflightWorld::Hoth;
    auto* LakeMesh=SurfaceMesh(Region,TEXT("LakeSurface"),Frozen ? TEXT("M_LakeIce") : TEXT("M_LakeWater"),true);
    FSurfaceDraft Draft;
    for (const auto& Lake : Lakes) {
        // Clip the lake against the same terrain triangles hit by the aircraft.
        // That makes the shoreline an intersection instead of a floating ellipse.
        for (int32 I=0; I<Triangles.Num(); I+=3) {
            FVector Triangle[3]={Terrain[Triangles[I]],Terrain[Triangles[I+1]],Terrain[Triangles[I+2]]};
            const auto First=starflight::FromUnreal({float(Triangle[0].X),float(Triangle[0].Y),float(Triangle[0].Z)});
            if (FMath::Abs(First.x-Lake.Centre.X)>Lake.Radii.X*1.25+100 ||
                FMath::Abs(First.z-Lake.Centre.Y)>Lake.Radii.Y*1.25+100) continue;
            auto SignedDistance=[&](const FVector& P) {
                const auto Native=starflight::FromUnreal({float(P.X),float(P.Y),float(P.Z)});
                return FMath::Max(Native.y-Lake.Level,(Lake.Distance(Native.x,Native.z)-1.09f)*95.f);
            };
            float Values[3]={SignedDistance(Triangle[0]),SignedDistance(Triangle[1]),SignedDistance(Triangle[2])};
            TArray<FVector,TInlineAllocator<4>> Clipped;
            for (int32 Edge=0; Edge<3; ++Edge) {
                const int32 Next=(Edge+1)%3;
                if (Values[Edge]<=0) Clipped.Add(Triangle[Edge]);
                if ((Values[Edge]<=0)!=(Values[Next]<=0)) {
                    Clipped.Add(FMath::Lerp(Triangle[Edge],Triangle[Next],Values[Edge]/(Values[Edge]-Values[Next])));
                }
            }
            if (Clipped.Num()<3) continue;
            const int32 Base=Draft.Points.Num();
            for (FVector P : Clipped) {
                const float Shore=1-Smooth(0,13,Lake.Level-float(P.Z/100));
                P.Z=Lake.Level*100;
                Draft.Add(P,FLinearColor(Shore,0,0));
            }
            for (int32 Corner=1; Corner+1<Clipped.Num(); ++Corner) Draft.Indices.Append({Base,Base+Corner,Base+Corner+1});
        }
    }
    Draft.Publish(*LakeMesh,true);
    Shoreline(Region,Lakes,Frozen);
    UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_LAKES %s: %d lakes, %d clipped collision triangles"),
        WorldName(World),Lakes.Num(),Draft.Indices.Num()/3);
}

void AddCityRoads(AStarflightRegion& Region) {
    auto* Roads=SurfaceMesh(Region,TEXT("CoruscantRoads"),TEXT("M_Road"),false);
    auto* Paint=SurfaceMesh(Region,TEXT("CoruscantLaneMarkings"),TEXT("M_LanePaint"),false);
    FSurfaceDraft Asphalt,Lines;
    constexpr float Limit=11280;
    constexpr float RoadWidth=56;
    for (int32 I=-23; I<=23; ++I) {
        const float Axis=I*480.f;
        Asphalt.Plate(Axis-RoadWidth,Axis+RoadWidth,-Limit,Limit,0.22);
        Asphalt.Plate(-Limit,Limit,Axis-RoadWidth,Axis+RoadWidth,0.26);
        for (float Side : {-1.f,1.f}) {
            const float Verge=Axis+Side*(RoadWidth-5);
            Lines.Plate(Verge-0.65f,Verge+0.65f,-Limit,Limit,0.31);
            Lines.Plate(-Limit,Limit,Verge-0.65f,Verge+0.65f,0.34);
        }
        for (int32 Mark=-93; Mark<=93; ++Mark) {
            const float P=Mark*120.f+60;
            if (FMath::Abs(P)-Limit>0) continue;
            Lines.Plate(Axis-1.15f,Axis+1.15f,P-21,P+21,0.38);
            Lines.Plate(P-21,P+21,Axis-1.15f,Axis+1.15f,0.40);
        }
    }
    Asphalt.Publish(*Roads,false);
    Lines.Publish(*Paint,false);
    UE_LOG(LogTemp,Display,TEXT("STARFLIGHT_ROADS: grid of connected city streets"));
}
