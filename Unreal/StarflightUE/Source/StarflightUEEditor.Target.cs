using UnrealBuildTool;
public class StarflightUEEditorTarget : TargetRules {
    public StarflightUEEditorTarget(TargetInfo Target) : base(Target) {
        Type=TargetType.Editor;
        DefaultBuildSettings=BuildSettingsVersion.V7;
        IncludeOrderVersion=EngineIncludeOrderVersion.Unreal5_8;
        ExtraModuleNames.Add("StarflightUE");
    }
}
