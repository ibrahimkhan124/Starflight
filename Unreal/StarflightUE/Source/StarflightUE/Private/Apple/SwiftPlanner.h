#pragma once
#include "CoreMinimal.h"

void OpenSwiftPlanner(int32 Current,const TArray<FString>& Ships,int32 ActiveShip,
    TFunction<void(int32,int32)> OnSelect);
