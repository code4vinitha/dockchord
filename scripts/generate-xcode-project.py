#!/usr/bin/env python3
"""Generate the dependency-free Xcode app target from the Swift source files."""
from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent.parent
project = root / 'DockChord.xcodeproj'
project.mkdir(exist_ok=True)
objects = {}
def add(key, kind, **values):
    identifier = hashlib.sha1(key.encode()).hexdigest()[:24].upper()
    objects[identifier] = {'isa': kind, **values}
    return identifier
refs, sources, resources = [], [], []
for path in sorted((root / 'Sources/DockChord').glob('*.swift')):
    path = str(path.relative_to(root))
    ref = add(path, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=path, sourceTree='<group>')
    refs.append(ref)
    sources.append(add('build:'+path, 'PBXBuildFile', fileRef=ref))
for path, kind in [('Resources/PrivacyInfo.xcprivacy','text.xml'), ('Configuration/Info.plist','text.plist.xml'), ('Configuration/Sandbox.entitlements','text.plist.entitlements'), ('Configuration/SandboxDock.entitlements','text.plist.entitlements')]:
    ref = add(path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
    refs.append(ref)
    if path.startswith('Resources/'):
        resources.append(add('build:'+path, 'PBXBuildFile', fileRef=ref))
product = add('product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='DockChord.app', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
main = add('main', 'PBXGroup', children=refs+[products], sourceTree='<group>')
phases = [add('sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0), add('resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0), add('frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)]
configs, project_configs = [], []
for name in ['Debug', 'Release', 'SandboxDockExperimental']:
    experimental = name == 'SandboxDockExperimental'
    settings = {'PRODUCT_NAME': 'DockChord', 'PRODUCT_BUNDLE_IDENTIFIER': 'io.github.code4vinitha.dockchord'+('.experimental' if experimental else ''), 'INFOPLIST_FILE': 'Configuration/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO', 'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_ENTITLEMENTS': 'Configuration/SandboxDock.entitlements' if experimental else 'Configuration/Sandbox.entitlements', 'ENABLE_APP_SANDBOX': 'YES', 'ENABLE_HARDENED_RUNTIME': 'YES', 'DOCKCHORD_DOCK_ACCESS': 'YES' if experimental else 'NO', 'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '1.0.0', 'SWIFT_VERSION': '5.0', 'MACOSX_DEPLOYMENT_TARGET': '13.0', 'COMBINE_HIDPI_IMAGES': 'YES', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym'}
    configs.append(add('target:'+name, 'XCBuildConfiguration', name=name, buildSettings=settings))
    project_configs.append(add('project:'+name, 'XCBuildConfiguration', name=name, buildSettings={'SDKROOT': 'macosx', 'MACOSX_DEPLOYMENT_TARGET': '13.0', 'CLANG_ENABLE_MODULES': 'YES'}))
list_t = add('targetConfigs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
list_p = add('projectConfigs', 'XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
target = add('app', 'PBXNativeTarget', buildConfigurationList=list_t, buildPhases=phases, buildRules=[], dependencies=[], name='DockChord', productName='DockChord', productReference=product, productType='com.apple.product-type.application')
proj = add('project', 'PBXProject', attributes={'LastUpgradeCheck': '2600'}, buildConfigurationList=list_p, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en','Base'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target])
def emit(value, level=0):
    if isinstance(value, dict):
        return '{\n'+''.join('\t'*(level+1)+json.dumps(str(k))+' = '+emit(v, level+1)+';\n' for k,v in value.items())+'\t'*level+'}'
    if isinstance(value, list): return '('+', '.join(emit(v, level) for v in value)+')'
    if isinstance(value, int): return str(value)
    return json.dumps(value)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+emit({'archiveVersion':1, 'classes':{}, 'objectVersion':56, 'objects':objects, 'rootObject':proj})+'\n')
schemes = project/'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DockChord.app" BlueprintName="DockChord" ReferencedContainer="container:DockChord.xcodeproj"/>'
(schemes/'DockChord.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated DockChord.xcodeproj')
