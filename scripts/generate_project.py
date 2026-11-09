"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
ROOT = Path(__file__).resolve().parent.parent
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value):
    objects[ident(name)] = value
    return ident(name)
def refs(names): return '(' + ', '.join(ident(n) for n in names) + ',)'
def cfg(name, settings):
    add(name, '{isa = XCBuildConfiguration; buildSettings = {' + settings + '}; name = ' + name.rsplit('.',1)[-1] + ';}')
files = sorted(p.name for p in (ROOT/'Moonbook').glob('*.swift'))
tests = sorted(p.name for p in (ROOT/'MoonbookTests').glob('*.swift'))
for folder, names in [('Moonbook',files),('MoonbookTests',tests)]:
    for f in names:
        add(f, '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+f+'"; sourceTree = "<group>";}')
        add('build.'+f, '{isa = PBXBuildFile; fileRef = '+ident(f)+';}')
    add(folder, '{isa = PBXGroup; children = '+refs(names)+'; path = '+folder+'; sourceTree = "<group>";}')
add('app.product','{isa = PBXFileReference; explicitFileType = wrapper.application; path = Moonbook.app; sourceTree = BUILT_PRODUCTS_DIR;}')
add('test.product','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MoonbookTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
add('products','{isa = PBXGroup; children = '+refs(['app.product','test.product'])+'; name = Products; sourceTree = "<group>";}')
add('root','{isa = PBXGroup; children = '+refs(['Moonbook','MoonbookTests','products'])+'; sourceTree = "<group>";}')
add('zip.package','{isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/weichsel/ZIPFoundation.git"; requirement = {kind = exactVersion; version = 0.9.19;};}')
add('zip.product','{isa = XCSwiftPackageProductDependency; package = '+ident('zip.package')+'; productName = ZIPFoundation;}')
add('zip.build','{isa = PBXBuildFile; productRef = '+ident('zip.product')+';}')
add('proxy','{isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+ident('app')+'; remoteInfo = Moonbook;}')
add('dependency','{isa = PBXTargetDependency; target = '+ident('app')+'; targetProxy = '+ident('proxy')+';}')
for target, names in [('app',files),('test',tests)]:
    add(target+'.sources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+refs(['build.'+f for f in names])+'; runOnlyForDeploymentPostprocessing = 0;}')
    add(target+'.frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = '+(refs(['zip.build']) if target == 'app' else '()')+'; runOnlyForDeploymentPostprocessing = 0;}')
    add(target+'.resources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}')
    for mode in ['Debug','Release']:
        settings = 'SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; '
        settings += 'ONLY_ACTIVE_ARCH = '+('YES' if mode == 'Debug' else 'NO')+'; '
        settings += 'SWIFT_OPTIMIZATION_LEVEL = '+('"-Onone"' if mode == 'Debug' else '"-O"')+'; '
        if target == 'app':
            settings += 'PRODUCT_NAME = Moonbook; PRODUCT_BUNDLE_IDENTIFIER = com.alicelikeeat.moonbook; MARKETING_VERSION = 0.2.0; CURRENT_PROJECT_VERSION = 2; INFOPLIST_KEY_CFBundleDisplayName = Moonbook; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; INFOPLIST_FILE = Moonbook/Info.plist; '
        else:
            settings += 'PRODUCT_NAME = MoonbookTests; PRODUCT_BUNDLE_IDENTIFIER = com.alicelikeeat.moonbook.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Moonbook.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Moonbook"; BUNDLE_LOADER = "$(TEST_HOST)"; '
        cfg(target+'.'+mode, settings)
    add(target+'.configs','{isa = XCConfigurationList; buildConfigurations = '+refs([target+'.Debug',target+'.Release'])+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
    add(target, '{isa = PBXNativeTarget; buildConfigurationList = '+ident(target+'.configs')+'; buildPhases = '+refs([target+'.sources',target+'.frameworks',target+'.resources'])+'; buildRules = (); dependencies = '+(refs(['dependency']) if target=='test' else '()')+'; name = '+('Moonbook' if target=='app' else 'MoonbookTests')+'; packageProductDependencies = '+(refs(['zip.product']) if target=='app' else '()')+'; productReference = '+ident(target+'.product')+'; productType = "'+('com.apple.product-type.application' if target=='app' else 'com.apple.product-type.bundle.unit-test')+'";}')
for mode in ['Debug','Release']:
    cfg('project.'+mode,'CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; ENABLE_TESTABILITY = '+('YES' if mode=='Debug' else 'NO')+';')
add('project.configs','{isa = XCConfigurationList; buildConfigurations = '+refs(['project.Debug','project.Release'])+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
add('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600;}; buildConfigurationList = '+ident('project.configs')+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; knownRegions = (zh_CN, en, Base); mainGroup = '+ident('root')+'; packageReferences = '+refs(['zip.package'])+'; productRefGroup = '+ident('products')+'; projectDirPath = ""; projectRoot = ""; targets = '+refs(['app','test'])+';}')
text = '// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
text += '\n'.join(k+' = '+v+';' for k,v in objects.items())
text += '\n}; rootObject = '+ident('project')+'; }\n'
(ROOT/'Moonbook.xcodeproj/project.pbxproj').write_text(text)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('app')}" BuildableName="Moonbook.app" BlueprintName="Moonbook" ReferencedContainer="container:Moonbook.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('test')}" BuildableName="MoonbookTests.xctest" BlueprintName="MoonbookTests" ReferencedContainer="container:Moonbook.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('app')}" BuildableName="Moonbook.app" BlueprintName="Moonbook" ReferencedContainer="container:Moonbook.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'Moonbook.xcodeproj/xcshareddata/xcschemes/Moonbook.xcscheme').write_text(scheme)
print('Generated Xcode project and shared scheme.')
