using UnrealBuildTool;
public class StarflightUETarget : TargetRules {
    public StarflightUETarget(TargetInfo Target) : base(Target) {
        Type=TargetType.Game;
        DefaultBuildSettings=BuildSettingsVersion.V7;
        IncludeOrderVersion=EngineIncludeOrderVersion.Unreal5_8;
        ExtraModuleNames.Add("StarflightUE");
    }
}
