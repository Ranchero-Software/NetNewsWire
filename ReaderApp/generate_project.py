#!/usr/bin/env python3
"""Generate the standalone Reader project using only the Python standard library."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
objects = {}


def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(name, value):
    key = ident(name)
    objects[key] = value
    return key


def quote(value):
    if isinstance(value, dict):
        return "{ " + " ".join(f"{quote(k)} = {quote(v)};" for k, v in value.items()) + " }"
    if isinstance(value, list):
        return "(" + ", ".join(quote(v) for v in value) + ",)" if value else "()"
    return json.dumps(str(value), ensure_ascii=False)


package = add("package", {"isa": "XCLocalSwiftPackageReference", "relativePath": "ReaderKit"})
products = []
for name in ["ReaderDomain", "ReaderPersistence", "ReaderSync", "ReaderContent", "ReaderIntelligence", "ReaderUI"]:
    products.append(add("product:" + name, {"isa": "XCSwiftPackageProductDependency", "package": package, "productName": name}))

file_ids = []


def source_phase(target, paths):
    build_files = []
    for path in paths:
        reference = add("file:" + path, {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift", "path": path, "sourceTree": "SOURCE_ROOT"})
        if reference not in file_ids:
            file_ids.append(reference)
        build_files.append(add("build:" + target + path, {"isa": "PBXBuildFile", "fileRef": reference}))
    return add("sources:" + target, {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647", "files": build_files, "runOnlyForDeploymentPostprocessing": "0"})


def frameworks(target, dependencies):
    files = [add("framework:" + target + product, {"isa": "PBXBuildFile", "productRef": product}) for product in dependencies]
    return add("frameworks:" + target, {"isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647", "files": files, "runOnlyForDeploymentPostprocessing": "0"})


def configurations(name, common, debug=None, release=None):
    refs = []
    for configuration, extra in [("Debug", debug or {}), ("Release", release or {})]:
        refs.append(add(name + configuration, {"isa": "XCBuildConfiguration", "buildSettings": {**common, **extra}, "name": configuration}))
    return add("configs:" + name, {"isa": "XCConfigurationList", "buildConfigurations": refs, "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"})


project_settings = {
    "MACOSX_DEPLOYMENT_TARGET": "27.0", "IPHONEOS_DEPLOYMENT_TARGET": "27.0", "SWIFT_VERSION": "6.2",
    "CLANG_ENABLE_MODULES": "YES", "SWIFT_STRICT_CONCURRENCY": "complete", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
}
project_configs = configurations("project", project_settings,
    {"SWIFT_OPTIMIZATION_LEVEL": "-Onone", "ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "ONLY_ACTIVE_ARCH": "YES"},
    {"SWIFT_COMPILATION_MODE": "wholemodule"})

app_id = ident("target:Reader")
app_product = add("app-product", {"isa": "PBXFileReference", "explicitFileType": "wrapper.application", "path": "Reader.app", "sourceTree": "BUILT_PRODUCTS_DIR"})
common = {
    "SDKROOT": "auto", "SUPPORTED_PLATFORMS": "macosx iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTS_MACCATALYST": "NO", "PRODUCT_NAME": "Reader", "PRODUCT_BUNDLE_IDENTIFIER": "eu.mpwg.reader",
    "INFOPLIST_FILE": "ReaderApp/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]": "ReaderApp/Reader.entitlements", "ENABLE_APP_SANDBOX": "YES",
    "ENABLE_HARDENED_RUNTIME": "YES", "SWIFT_EMIT_LOC_STRINGS": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../Frameworks",
}
app_configs = configurations("app", common, {"PRODUCT_BUNDLE_IDENTIFIER": "eu.mpwg.reader.debug"})
add("target:Reader", {"isa": "PBXNativeTarget", "buildConfigurationList": app_configs,
    "buildPhases": [source_phase("app", ["ReaderApp/ReaderApp.swift"]), frameworks("app", products)],
    "buildRules": [], "dependencies": [], "name": "Reader", "packageProductDependencies": products,
    "productName": "Reader", "productReference": app_product, "productType": "com.apple.product-type.application"})

test_targets = []
test_products = []
for name, ui in [("ReaderContractTests", False), ("ReaderSmokeTests", True)]:
    product = add("product:" + name, {"isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle", "path": name + ".xctest", "sourceTree": "BUILT_PRODUCTS_DIR"})
    test_products.append(product)
    source_paths = ["ReaderApp/Tests/SmokeTests.swift"] if ui else sorted(str(p.relative_to(ROOT)) for p in (ROOT / "ReaderKit/Tests").rglob("*.swift"))
    settings = {"SDKROOT": "auto", "SUPPORTED_PLATFORMS": "macosx iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "1,2",
        "PRODUCT_NAME": name, "PRODUCT_BUNDLE_IDENTIFIER": "eu.mpwg.reader.tests." + name.lower(),
        "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic"}
    if ui:
        settings["TEST_TARGET_NAME"] = "Reader"
    config = configurations(name, settings)
    dependency = add("dependency:" + name, {"isa": "PBXTargetDependency", "target": app_id})
    target = add("target:" + name, {"isa": "PBXNativeTarget", "buildConfigurationList": config,
        "buildPhases": [source_phase(name, source_paths), frameworks(name, [] if ui else products)], "buildRules": [],
        "dependencies": [dependency], "name": name, "packageProductDependencies": [] if ui else products,
        "productName": name, "productReference": product,
        "productType": "com.apple.product-type.bundle.ui-testing" if ui else "com.apple.product-type.bundle.unit-test"})
    test_targets.append(target)

products_group = add("products", {"isa": "PBXGroup", "children": [app_product, *test_products], "name": "Products", "sourceTree": "<group>"})
group = add("main-group", {"isa": "PBXGroup", "children": [*file_ids, products_group], "sourceTree": "<group>"})
project = add("project", {"isa": "PBXProject", "attributes": {"LastUpgradeCheck": "2710", "BuildIndependentTargetsInParallel": "YES"},
    "buildConfigurationList": project_configs, "compatibilityVersion": "Xcode 15.0", "developmentRegion": "de",
    "knownRegions": ["de", "en", "Base"], "mainGroup": group, "productRefGroup": products_group,
    "projectDirPath": "", "projectRoot": "", "packageReferences": [package], "targets": [app_id, *test_targets]})
document = {"archiveVersion": "1", "classes": {}, "objectVersion": "60", "objects": objects, "rootObject": project}
(ROOT / "Reader.xcodeproj/project.pbxproj").write_text("// !$*UTF8*$!\n" + quote(document) + "\n")

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_id}" BuildableName="Reader.app" BlueprintName="Reader" ReferencedContainer="container:Reader.xcodeproj"/>
    </BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <TestPlans><TestPlanReference reference="container:ReaderApp/Reader.xctestplan" default="YES"/></TestPlans>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_id}" BuildableName="Reader.app" BlueprintName="Reader" ReferencedContainer="container:Reader.xcodeproj"/></BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(ROOT / "Reader.xcodeproj/xcshareddata/xcschemes/Reader.xcscheme").write_text(scheme)
plan = {"configurations": [{"id": "E373F31C-94B3-4AE4-9923-756B8F8359E3", "name": "Reader", "options": {}}],
    "defaultOptions": {"targetForVariableExpansion": {"containerPath": "container:Reader.xcodeproj", "identifier": app_id, "name": "Reader"}},
    "testTargets": [{"target": {"containerPath": "container:Reader.xcodeproj", "identifier": target, "name": name}}
        for target, name in zip(test_targets, ["ReaderContractTests", "ReaderSmokeTests"])], "version": 1}
(ROOT / "ReaderApp/Reader.xctestplan").write_text(json.dumps(plan, indent=2) + "\n")
