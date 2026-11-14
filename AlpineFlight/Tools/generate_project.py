#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project after adding Swift sources."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def quote(value): return json.dumps(str(value))
def obj(name, body):
    key = uid(name)
    objects[key] = '{ ' + body + ' };'
    return key
def array(values): return '(' + ', '.join(values) + ',)'
def ref(path, file_type):
    return obj('file:' + path, f'isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quote(path)}; sourceTree = "<group>";')
def build(path, file_type):
    file_id = ref(path, file_type)
    return obj('build:' + path, f'isa = PBXBuildFile; fileRef = {file_id};'), file_id

target_names = ['AlpineFlight', 'AlpineFlightTests', 'AlpineFlightUITests']
groups, products, targets = [], [], []
common = {'CLANG_ENABLE_MODULES': 'YES', 'IPHONEOS_DEPLOYMENT_TARGET': '26.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0', 'TARGETED_DEVICE_FAMILY': '1,2', 'CODE_SIGN_STYLE': 'Automatic', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'}
def config_list(name, settings):
    configs = []
    for config in ['Debug', 'Release']:
        values = dict(settings)
        values.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym'})
        if config == 'Debug':
            values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
            values['ENABLE_TESTABILITY'] = 'YES'
        body = ' '.join(f'{k} = {quote(v)};' for k, v in values.items())
        configs.append(obj(f'{name}:{config}', f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};'))
    return obj(f'{name}:configs', f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

for name in target_names:
    is_app = name == 'AlpineFlight'
    sources, children = [], []
    for file in sorted((ROOT / name).rglob('*.swift')):
        build_id, file_id = build(str(file.relative_to(ROOT)), 'sourcecode.swift')
        sources.append(build_id); children.append(file_id)
    resources = []
    if is_app:
        for path, kind in [
            ('AlpineFlight/Resources/Assets.xcassets', 'folder.assetcatalog'),
            ('AlpineFlight/Resources/Audio', 'folder'),
            ('AlpineFlight/Resources/StarflightIntro.mp4', 'video.mp4'),
            ('AlpineFlight/Resources/BlenderAssets', 'folder'),
            *[(f'AlpineFlight/Resources/{x}.wav', 'audio.wav') for x in ['engine', 'impact', 'checkpoint', 'jet', 'laser']],
        ]:
            b, f = build(path, kind); resources.append(b); children.append(f)
        children.append(ref('AlpineFlight/Resources/Info.plist', 'text.plist.xml'))
    groups.append(obj(name + ':group', f'isa = PBXGroup; children = {array(children)}; name = {name}; sourceTree = "<group>";'))
    ext = 'app' if is_app else 'xctest'
    product = obj(name + ':product', f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if is_app else "wrapper.cfbundle"}; includeInIndex = 0; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    phases = []
    for kind, files in [('Sources', sources), ('Frameworks', []), ('Resources', resources)]:
        phases.append(obj(name + ':' + kind, f'isa = PBX{kind}BuildPhase; buildActionMask = 2147483647; files = {array(files) if files else "()"}; runOnlyForDeploymentPostprocessing = 0;'))
    settings = dict(common)
    settings.update({'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.alpineflight.prototype' + ('' if is_app else '.' + name), 'GENERATE_INFOPLIST_FILE': 'NO' if is_app else 'YES', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO'})
    if is_app:
        settings.update({'INFOPLIST_FILE': 'AlpineFlight/Resources/Info.plist', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator macosx', 'SUPPORTS_MACCATALYST': 'YES', 'MACOSX_DEPLOYMENT_TARGET': '15.0', '"IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"': '18.0'})
    elif name == 'AlpineFlightTests':
        settings.update({'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/AlpineFlight.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AlpineFlight', 'BUNDLE_LOADER': '$(TEST_HOST)'})
    else:
        settings['TEST_TARGET_NAME'] = 'AlpineFlight'
    deps = []
    if not is_app:
        proxy = obj(name + ':proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("AlpineFlight:target")}; remoteInfo = AlpineFlight;')
        deps.append(obj(name + ':dependency', f'isa = PBXTargetDependency; target = {uid("AlpineFlight:target")}; targetProxy = {proxy};'))
    kind = 'application' if is_app else 'bundle.unit-test' if name == 'AlpineFlightTests' else 'bundle.ui-testing'
    targets.append(obj(name + ':target', f'isa = PBXNativeTarget; buildConfigurationList = {config_list(name, settings)}; buildPhases = {array(phases)}; buildRules = (); dependencies = {array(deps) if deps else "()"}; name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{kind}";'))

groups.append(obj('products', f'isa = PBXGroup; children = {array(products)}; name = Products; sourceTree = "<group>";'))
main = obj('main', f'isa = PBXGroup; children = {array(groups)}; sourceTree = "<group>";')
project = obj('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2600; }}; buildConfigurationList = {config_list("project", common)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
project_dir = ROOT / 'AlpineFlight.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\narchiveVersion = 1;\nclasses = {};\nobjectVersion = 56;\nobjects = {\n' + '\n'.join(k + ' = ' + v for k, v in objects.items()) + f'\n}};\nrootObject = {project};\n}}\n')

def buildable(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name + ":target")}" BuildableName="{name}.{"app" if name == "AlpineFlight" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:AlpineFlight.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('AlpineFlight')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
{''.join(f'<TestableReference skipped="NO" parallelizable="NO">{buildable(n)}</TestableReference>' for n in target_names[1:])}
</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('AlpineFlight')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('AlpineFlight')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir = project_dir / 'xcshareddata' / 'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / 'AlpineFlight.xcscheme').write_text(scheme)
print('Generated AlpineFlight.xcodeproj with app, unit tests, and UI tests.')
