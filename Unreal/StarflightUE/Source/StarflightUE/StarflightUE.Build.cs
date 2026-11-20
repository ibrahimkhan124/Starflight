using UnrealBuildTool;
using System.IO;
public class StarflightUE : ModuleRules {
    public StarflightUE(ReadOnlyTargetRules Target) : base(Target) {
        PCHUsage=PCHUsageMode.UseExplicitOrSharedPCHs;
        CppStandard=CppStandardVersion.Cpp20;
        if (Target.Platform == UnrealTargetPlatform.Mac || Target.Platform == UnrealTargetPlatform.IOS)
        {
            PublicFrameworks.Add("SwiftUI");
            SwiftInteropHeader = Path.Combine(ModuleDirectory, "Private/Apple/SwiftInterop.h");
        }
        PublicDependencyModuleNames.AddRange(new string[] {"Core","CoreUObject","Engine","InputCore","ProceduralMeshComponent"});
    }
}
