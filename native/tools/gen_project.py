#!/usr/bin/env python3
"""Generate DigiCash.xcodeproj/project.pbxproj deterministically.

Run from native/:  python3 tools/gen_project.py
"""
import hashlib, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ_DIR = os.path.join(ROOT, "DigiCash.xcodeproj")

# (path relative to ROOT, target membership)
APP_SOURCES = [
    "DigiCash/DigiCashApp.swift",
    "DigiCash/Design/Theme.swift",
    "DigiCash/Design/Components.swift",
    "DigiCash/Core/Money.swift",
    "DigiCash/Core/Models.swift",
    "DigiCash/Core/DataStore.swift",
    "DigiCash/Core/Finance.swift",
    "DigiCash/Core/Notifications.swift",
    "DigiCash/Features/RootView.swift",
    "DigiCash/Features/OnboardingView.swift",
    "DigiCash/Features/HomeView.swift",
    "DigiCash/Features/TransactionsView.swift",
    "DigiCash/Features/TransactionFormView.swift",
    "DigiCash/Features/AccountsView.swift",
    "DigiCash/Features/BudgetsView.swift",
    "DigiCash/Features/GoalsView.swift",
    "DigiCash/Features/InsightsView.swift",
    "DigiCash/Features/RecurringView.swift",
    "DigiCash/Features/SettingsView.swift",
]
APP_RESOURCES = ["DigiCash/Resources/Assets.xcassets"]
TEST_SOURCES = [
    "DigiCashTests/MoneyTests.swift",
    "DigiCashTests/FinanceTests.swift",
]

def uid(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

def fileref(path: str) -> str:
    return uid("fileref:" + path)

def buildfile(path: str) -> str:
    return uid("buildfile:" + path)

def main():
    missing = [p for p in APP_SOURCES + APP_RESOURCES + TEST_SOURCES
               if not os.path.exists(os.path.join(ROOT, p))]
    if missing:
        print("MISSING FILES:", missing, file=sys.stderr)
        sys.exit(1)

    # UUIDs
    project_id = uid("project")
    app_target = uid("target:app")
    test_target = uid("target:test")
    app_ph_sources = uid("phase:app:sources")
    app_ph_resources = uid("phase:app:resources")
    app_ph_frameworks = uid("phase:app:frameworks")
    test_ph_sources = uid("phase:test:sources")
    test_ph_frameworks = uid("phase:test:frameworks")
    app_config_list = uid("configlist:app")
    test_config_list = uid("configlist:test")
    proj_config_list = uid("configlist:proj")
    app_debug = uid("config:app:debug")
    app_release = uid("config:app:release")
    test_debug = uid("config:test:debug")
    test_release = uid("config:test:release")
    proj_debug = uid("config:proj:debug")
    proj_release = uid("config:proj:release")
    main_group = uid("group:main")
    app_group = uid("group:app")
    design_group = uid("group:design")
    core_group = uid("group:core")
    features_group = uid("group:features")
    resources_group = uid("group:resources")
    tests_group = uid("group:tests")
    products_group = uid("group:products")
    app_product_ref = uid("product:app")
    test_product_ref = uid("product:test")
    app_dep = uid("dep:app->test")

    L = []
    def emit(s=""):
        L.append(s)

    emit("// !$*UTF8*$!")
    emit("{")
    emit("\tarchiveVersion = 1;")
    emit("\tclasses = {")
    emit("\t};")
    emit("\tobjectVersion = 60;")
    emit("\tobjects = {")

    # ---------- PBXBuildFile ----------
    emit("/* Begin PBXBuildFile section */")
    for p in APP_SOURCES:
        emit(f"\t\t{buildfile(p)} = {{isa = PBXBuildFile; fileRef = {fileref(p)}; }};")
    for p in APP_RESOURCES:
        emit(f"\t\t{buildfile(p)} = {{isa = PBXBuildFile; fileRef = {fileref(p)}; }};")
    for p in TEST_SOURCES:
        emit(f"\t\t{buildfile(p)} = {{isa = PBXBuildFile; fileRef = {fileref(p)}; }};")
    emit("/* End PBXBuildFile section */")
    emit("")

    # ---------- PBXFileReference ----------
    emit("/* Begin PBXFileReference section */")
    for p in APP_SOURCES + TEST_SOURCES:
        emit(f'\t\t{fileref(p)} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{os.path.basename(p)}"; sourceTree = "<group>"; }};')
    for p in APP_RESOURCES:
        emit(f'\t\t{fileref(p)} = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    emit(f'\t\t{app_product_ref} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DigiCash.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    emit(f'\t\t{test_product_ref} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = DigiCashTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
    emit("/* End PBXFileReference section */")
    emit("")

    # ---------- PBXFrameworksBuildPhase ----------
    emit("/* Begin PBXFrameworksBuildPhase section */")
    emit(f"\t\t{app_ph_frameworks} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    emit(f"\t\t{test_ph_frameworks} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    emit("/* End PBXFrameworksBuildPhase section */")
    emit("")

    # ---------- PBXGroup ----------
    emit("/* Begin PBXGroup section */")
    def group(gid, name, children, path=None):
        kids = ",\n".join(f"\t\t\t\t{c}" for c in children)
        p = f'path = "{path}"; ' if path else ""
        emit(f"\t\t{gid} = {{")
        emit(f"\t\t\tisa = PBXGroup;")
        emit(f"\t\t\tchildren = (")
        if kids:
            emit(kids + ",")
        emit(f"\t\t\t);")
        emit(f'\t\t\t{name and f"name = {name}; " or ""}{p}sourceTree = "<group>";')
        emit(f"\t\t}};")
    group(main_group, None, [app_group, tests_group, products_group])
    group(app_group, "DigiCash", [fileref("DigiCash/DigiCashApp.swift"), design_group, core_group, features_group, resources_group], path="DigiCash")
    group(design_group, "Design", [fileref(p) for p in APP_SOURCES if "/Design/" in p])
    group(core_group, "Core", [fileref(p) for p in APP_SOURCES if "/Core/" in p])
    group(features_group, "Features", [fileref(p) for p in APP_SOURCES if "/Features/" in p])
    group(resources_group, "Resources", [fileref(p) for p in APP_RESOURCES], path="Resources")
    group(tests_group, "DigiCashTests", [fileref(p) for p in TEST_SOURCES], path="DigiCashTests")
    group(products_group, "Products", [app_product_ref, test_product_ref], )
    emit("/* End PBXGroup section */")
    emit("")

    # ---------- PBXNativeTarget ----------
    emit("/* Begin PBXNativeTarget section */")
    emit(f"\t\t{app_target} = {{")
    emit("\t\t\tisa = PBXNativeTarget;")
    emit(f"\t\t\tbuildConfigurationList = {app_config_list};")
    emit("\t\t\tbuildPhases = (")
    emit(f"\t\t\t\t{app_ph_sources},")
    emit(f"\t\t\t\t{app_ph_frameworks},")
    emit(f"\t\t\t\t{app_ph_resources},")
    emit("\t\t\t);")
    emit("\t\t\tbuildRules = (")
    emit("\t\t\t);")
    emit("\t\t\tdependencies = (")
    emit("\t\t\t);")
    emit('\t\t\tname = DigiCash;')
    emit('\t\t\tproductName = DigiCash;')
    emit(f"\t\t\tproductReference = {app_product_ref};")
    emit('\t\t\tproductType = "com.apple.product-type.application";')
    emit("\t\t};")
    emit(f"\t\t{test_target} = {{")
    emit("\t\t\tisa = PBXNativeTarget;")
    emit(f"\t\t\tbuildConfigurationList = {test_config_list};")
    emit("\t\t\tbuildPhases = (")
    emit(f"\t\t\t\t{test_ph_sources},")
    emit(f"\t\t\t\t{test_ph_frameworks},")
    emit("\t\t\t);")
    emit("\t\t\tbuildRules = (")
    emit("\t\t\t);")
    emit("\t\t\tdependencies = (")
    emit(f"\t\t\t\t{app_dep},")
    emit("\t\t\t);")
    emit('\t\t\tname = DigiCashTests;')
    emit('\t\t\tproductName = DigiCashTests;')
    emit(f"\t\t\tproductReference = {test_product_ref};")
    emit('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
    emit("\t\t};")
    emit("/* End PBXNativeTarget section */")
    emit("")

    # ---------- PBXProject ----------
    emit("/* Begin PBXProject section */")
    emit(f"\t\t{project_id} = {{")
    emit("\t\t\tisa = PBXProject;")
    emit("\t\t\tattributes = {")
    emit("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    emit("\t\t\t\tLastUpgradeCheck = 1620;")
    emit("\t\t\t\tTargetAttributes = {")
    emit(f"\t\t\t\t\t{app_target} = {{")
    emit("\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;")
    emit("\t\t\t\t\t};")
    emit(f"\t\t\t\t\t{test_target} = {{")
    emit("\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;")
    emit("\t\t\t\t\t\tTestTargetID = " + app_target + ";")
    emit("\t\t\t\t\t};")
    emit("\t\t\t\t};")
    emit("\t\t\t};")
    emit(f"\t\t\tbuildConfigurationList = {proj_config_list};")
    emit("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    emit("\t\t\tdevelopmentRegion = en;")
    emit("\t\t\thasScannedForEncodings = 0;")
    emit("\t\t\tknownRegions = (en);")
    emit(f"\t\t\tmainGroup = {main_group};")
    emit(f"\t\t\tproductRefGroup = {products_group};")
    emit("\t\t\tprojectDirPath = \"\";")
    emit("\t\t\tprojectRoot = \"\";")
    emit("\t\t\ttargets = (")
    emit(f"\t\t\t\t{app_target},")
    emit(f"\t\t\t\t{test_target},")
    emit("\t\t\t);")
    emit("\t\t};")
    emit("/* End PBXProject section */")
    emit("")

    # ---------- PBXResourcesBuildPhase / PBXSourcesBuildPhase ----------
    emit("/* Begin PBXResourcesBuildPhase section */")
    emit(f"\t\t{app_ph_resources} = {{")
    emit("\t\t\tisa = PBXResourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for p in APP_RESOURCES:
        emit(f"\t\t\t\t{buildfile(p)},")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXResourcesBuildPhase section */")
    emit("")
    emit("/* Begin PBXSourcesBuildPhase section */")
    emit(f"\t\t{app_ph_sources} = {{")
    emit("\t\t\tisa = PBXSourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for p in APP_SOURCES:
        emit(f"\t\t\t\t{buildfile(p)},")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit(f"\t\t{test_ph_sources} = {{")
    emit("\t\t\tisa = PBXSourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for p in TEST_SOURCES:
        emit(f"\t\t\t\t{buildfile(p)},")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXSourcesBuildPhase section */")
    emit("")

    # ---------- PBXTargetDependency ----------
    emit("/* Begin PBXTargetDependency section */")
    emit(f"\t\t{app_dep} = {{isa = PBXTargetDependency; target = {app_target}; targetProxy = {uid('proxy:app')}; }};")
    emit("/* End PBXTargetDependency section */")
    emit("")
    emit("/* Begin PBXContainerItemProxy section */")
    emit(f"\t\t{uid('proxy:app')} = {{")
    emit("\t\t\tisa = PBXContainerItemProxy;")
    emit(f"\t\t\tcontainerPortal = {project_id};")
    emit("\t\t\tproxyType = 1;")
    emit(f"\t\t\tremoteGlobalIDString = {app_target};")
    emit('\t\t\tremoteInfo = DigiCash;')
    emit("\t\t};")
    emit("/* End PBXContainerItemProxy section */")
    emit("")

    # ---------- XCBuildConfiguration ----------
    emit("/* Begin XCBuildConfiguration section */")

    def config(cid, name, settings):
        emit(f"\t\t{cid} = {{")
        emit("\t\t\tisa = XCBuildConfiguration;")
        emit("\t\t\tbuildSettings = {")
        for k, v in settings.items():
            emit(f"\t\t\t\t{k} = {v};")
        emit("\t\t\t};")
        emit(f"\t\t\tname = {name};")
        emit("\t\t};")

    proj_base = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "CURRENT_PROJECT_VERSION": "1",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "MARKETING_VERSION": "1.0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
    }
    config(proj_debug, "Debug", {**proj_base,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
    })
    config(proj_release, "Release", {**proj_base,
        "COPY_PHASE_STRIP": "YES",
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    })

    app_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_ASSET_PATHS": '"DigiCash/Resources/Preview Content"',
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "DigiCash",
        "INFOPLIST_KEY_LSRequiresIPhoneOS": "YES",
        "INFOPLIST_KEY_NSFaceIDUsageDescription": '"Unlock DigiCash with Face ID or Touch ID."',
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.digicash.app",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": '"1,2"',
    }
    config(app_debug, "Debug", {**app_common,
        "CODE_SIGN_IDENTITY": '"-"',
        "CODE_SIGNING_REQUIRED": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
    })
    config(app_release, "Release", {**app_common,
        "CODE_SIGN_IDENTITY": '"Apple Development"',
        "COPY_PHASE_STRIP": "YES",
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    })

    test_common = {
        "BUNDLE_LOADER": '"$(TEST_HOST)"',
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.digicash.app.tests",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": '"1,2"',
        "TEST_HOST": '"$(BUILT_PRODUCTS_DIR)/DigiCash.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/DigiCash"',
    }
    config(test_debug, "Debug", {**test_common,
        "CODE_SIGN_IDENTITY": '"-"',
        "CODE_SIGNING_REQUIRED": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
    })
    config(test_release, "Release", {**test_common,
        "CODE_SIGN_IDENTITY": '"Apple Development"',
        "COPY_PHASE_STRIP": "YES",
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    })
    emit("/* End XCBuildConfiguration section */")
    emit("")

    # ---------- XCConfigurationList ----------
    emit("/* Begin XCConfigurationList section */")
    for lid, cfgs in [(app_config_list, [app_debug, app_release]),
                      (test_config_list, [test_debug, test_release]),
                      (proj_config_list, [proj_debug, proj_release])]:
        emit(f"\t\t{lid} = {{")
        emit("\t\t\tisa = XCConfigurationList;")
        emit("\t\t\tbuildConfigurations = (")
        for c in cfgs:
            emit(f"\t\t\t\t{c},")
        emit("\t\t\t);")
        emit("\t\t\tdefaultConfigurationIsVisible = 0;")
        emit('\t\t\tdefaultConfigurationName = Release;')
        emit("\t\t};")
    emit("/* End XCConfigurationList section */")
    emit("")
    emit("\t};")
    emit("\trootObject = " + project_id + ";")
    emit("}")

    os.makedirs(PROJ_DIR, exist_ok=True)
    with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as f:
        f.write("\n".join(L) + "\n")
    print("Wrote", os.path.join(PROJ_DIR, "project.pbxproj"))

if __name__ == "__main__":
    main()
