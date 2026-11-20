#include "CoreMinimal.h"
#include "Apple/SwiftPlanner.h"

#if PLATFORM_MAC || PLATFORM_IOS
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#include "Async/Async.h"

@interface StarflightSwiftUI : NSObject
+ (void)present:(int32_t)current ships:(NSArray<NSString*>*)ships activeShip:(int32_t)activeShip
       onSelect:(void (^)(int32_t,int32_t))onSelect;
@end

void OpenSwiftPlanner(int32 Current,const TArray<FString>& Ships,int32 ActiveShip,
    TFunction<void(int32,int32)> OnSelect) {
    auto Callback=MakeShared<TFunction<void(int32,int32)>,ESPMode::ThreadSafe>(MoveTemp(OnSelect));
    NSMutableArray<NSString*>* Names=[NSMutableArray arrayWithCapacity:Ships.Num()];
    for (const FString& Name : Ships) [Names addObject:[NSString stringWithUTF8String:TCHAR_TO_UTF8(*Name)]];
    [StarflightSwiftUI present:Current ships:Names activeShip:ActiveShip onSelect:^(int32_t World,int32_t Ship) {
        AsyncTask(ENamedThreads::GameThread,[Callback,World,Ship] { (*Callback)(World,Ship); });
    }];
}
#endif
