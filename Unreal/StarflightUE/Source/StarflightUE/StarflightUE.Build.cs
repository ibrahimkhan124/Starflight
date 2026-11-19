using UnrealBuildTool;
public class StarflightUE : ModuleRules {
    public StarflightUE(ReadOnlyTargetRules Target) : base(Target) {
        PCHUsage=PCHUsageMode.UseExplicitOrSharedPCHs;
        CppStandard=CppStandardVersion.Cpp20;
        PublicDependencyModuleNames.AddRange(new string[] {"Core","CoreUObject","Engine","InputCore","ProceduralMeshComponent"});
    }
}
