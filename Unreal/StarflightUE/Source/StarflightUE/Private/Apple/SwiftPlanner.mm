#include "CoreMinimal.h"
#include "Apple/SwiftPlanner.h"

#if PLATFORM_MAC || PLATFORM_IOS
#import <Foundation/NSObject.h>
#include "Async/Async.h"

// Starflight SwiftUI exports this Objective-C selector. Keep the surface narrow.
@interface StarflightSwiftUI : NSObject
+ (void)present:(int32_t)current onSelect:(void (^)(int32_t))onSelect;
@end

void OpenSwiftPlanner(int32 Current, TFunction<void(int32)> OnSelect) {
    auto Callback = MakeShared<TFunction<void(int32)>,ESPMode::ThreadSafe>(MoveTemp(OnSelect));
    [StarflightSwiftUI present:Current onSelect:^(int32_t Selected) {
        AsyncTask(ENamedThreads::GameThread,[Callback,Selected] { (*Callback)(Selected); });
    }];
}
#endif
