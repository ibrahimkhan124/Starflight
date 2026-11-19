using UnrealBuildTool;
public class StarflightUETarget : TargetRules {
    public StarflightUETarget(TargetInfo Target) : base(Target) {
        Type=TargetType.Game;
        DefaultBuildSettings=BuildSettingsVersion.V5;
        ExtraModuleNames.Add("StarflightUE");
    }
}
