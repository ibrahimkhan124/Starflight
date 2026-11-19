using UnrealBuildTool;
public class StarflightUEEditorTarget : TargetRules {
    public StarflightUEEditorTarget(TargetInfo Target) : base(Target) {
        Type=TargetType.Editor;
        DefaultBuildSettings=BuildSettingsVersion.V5;
        ExtraModuleNames.Add("StarflightUE");
    }
}
