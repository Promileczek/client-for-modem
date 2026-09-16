#!/usr/bin/env python3
"""Generuje ModemClient.xcodeproj z plikow zrodlowych w ModemClient/.

Uruchamiany na Windowsie (nie wymaga Xcode). Wynik jest commitowany do repo,
zeby runner macOS w CI mial gotowy projekt do zbudowania.

Uzycie:  python tools/generate_xcodeproj.py
"""

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "ModemClient"
PROJECT_NAME = "ModemClient"
BUNDLE_ID = "com.modemclient.app"
DEPLOYMENT_TARGET = "16.0"


def uid(name: str) -> str:
    """Deterministyczny 24-znakowy identyfikator w stylu Xcode."""
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def find_swift_files():
    files = []
    for path in sorted(SRC_DIR.rglob("*.swift")):
        files.append(path.relative_to(SRC_DIR).as_posix())
    return files


def group_tree(files):
    """Buduje mape katalog -> lista plikow, zachowujac strukture folderow."""
    tree = {}
    for f in files:
        parts = f.split("/")
        folder = "/".join(parts[:-1])
        tree.setdefault(folder, []).append(f)
    return tree


def main():
    swift_files = find_swift_files()
    if not swift_files:
        raise SystemExit("Nie znaleziono plikow .swift w ModemClient/")

    tree = group_tree(swift_files)

    # --- Sekcja PBXBuildFile / PBXFileReference ---
    build_files = []
    file_refs = []
    sources_entries = []

    for f in swift_files:
        basename = f.split("/")[-1]
        fref = uid("fileref:" + f)
        bfile = uid("buildfile:" + f)
        file_refs.append(
            f'\t\t{fref} /* {basename} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = "{basename}"; '
            f'sourceTree = "<group>"; }};'
        )
        build_files.append(
            f'\t\t{bfile} /* {basename} in Sources */ = {{isa = PBXBuildFile; '
            f'fileRef = {fref} /* {basename} */; }};'
        )
        sources_entries.append(f'\t\t\t\t{bfile} /* {basename} in Sources */,')

    plist_ref = uid("fileref:Info.plist")
    file_refs.append(
        f'\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; '
        f'lastKnownFileType = text.plist.xml; path = Info.plist; '
        f'sourceTree = "<group>"; }};'
    )

    product_ref = uid("product")
    file_refs.append(
        f'\t\t{product_ref} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; '
        f'explicitFileType = wrapper.application; includeInIndex = 0; '
        f'path = "{PROJECT_NAME}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )

    # --- Grupy ---
    groups = []
    subgroup_refs = []

    for folder in sorted(k for k in tree if k):
        gref = uid("group:" + folder)
        children = "\n".join(
            f'\t\t\t\t{uid("fileref:" + f)} /* {f.split("/")[-1]} */,'
            for f in sorted(tree[folder])
        )
        groups.append(
            f'\t\t{gref} /* {folder} */ = {{\n'
            f'\t\t\tisa = PBXGroup;\n'
            f'\t\t\tchildren = (\n{children}\n\t\t\t);\n'
            f'\t\t\tpath = "{folder}";\n'
            f'\t\t\tsourceTree = "<group>";\n'
            f'\t\t}};'
        )
        subgroup_refs.append(f'\t\t\t\t{gref} /* {folder} */,')

    root_files = sorted(tree.get("", []))
    root_children = "\n".join(
        f'\t\t\t\t{uid("fileref:" + f)} /* {f.split("/")[-1]} */,' for f in root_files
    )
    app_group = uid("group:app")
    groups.append(
        f'\t\t{app_group} /* {PROJECT_NAME} */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        + (root_children + "\n" if root_children else "")
        + "\n".join(subgroup_refs) + "\n"
        f'\t\t\t\t{plist_ref} /* Info.plist */,\n'
        f'\t\t\t);\n'
        f'\t\t\tpath = "{PROJECT_NAME}";\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    products_group = uid("group:products")
    groups.append(
        f'\t\t{products_group} /* Products */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n\t\t\t\t{product_ref} /* {PROJECT_NAME}.app */,\n\t\t\t);\n'
        f'\t\t\tname = Products;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    main_group = uid("group:main")
    groups.append(
        f'\t\t{main_group} = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t{app_group} /* {PROJECT_NAME} */,\n'
        f'\t\t\t\t{products_group} /* Products */,\n'
        f'\t\t\t);\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    # --- Identyfikatory faz i konfiguracji ---
    target_id = uid("target")
    project_id = uid("project")
    sources_phase = uid("phase:sources")
    frameworks_phase = uid("phase:frameworks")
    resources_phase = uid("phase:resources")
    proj_debug = uid("conf:projdebug")
    proj_release = uid("conf:projrelease")
    tgt_debug = uid("conf:tgtdebug")
    tgt_release = uid("conf:tgtrelease")
    proj_conf_list = uid("conflist:proj")
    tgt_conf_list = uid("conflist:tgt")

    common_project_settings = f"""\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

    common_target_settings = f"""\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "{PROJECT_NAME}/Info.plist";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;"""

    pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* {PROJECT_NAME} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {tgt_conf_list} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{frameworks_phase} /* Frameworks */,
\t\t\t\t{resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = "{PROJECT_NAME}";
\t\t\tproductName = "{PROJECT_NAME}";
\t\t\tproductReference = {product_ref} /* {PROJECT_NAME}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_conf_list} /* Build configuration list for PBXProject "{PROJECT_NAME}" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* {PROJECT_NAME} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(sources_entries)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{proj_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_project_settings}
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_project_settings}
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{tgt_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_target_settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{tgt_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_target_settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_conf_list} /* Build configuration list for PBXProject "{PROJECT_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug} /* Debug */,
\t\t\t\t{proj_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{tgt_conf_list} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{tgt_debug} /* Debug */,
\t\t\t\t{tgt_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {project_id} /* Project object */;
}}
"""

    proj_dir = ROOT / f"{PROJECT_NAME}.xcodeproj"
    proj_dir.mkdir(exist_ok=True)
    (proj_dir / "project.pbxproj").write_text(pbxproj, encoding="utf-8", newline="\n")

    # Schemat potrzebny, zeby xcodebuild -scheme dzialalo w CI.
    schemes_dir = proj_dir / "xcshareddata" / "xcschemes"
    schemes_dir.mkdir(parents=True, exist_ok=True)
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (schemes_dir / f"{PROJECT_NAME}.xcscheme").write_text(scheme, encoding="utf-8", newline="\n")

    print(f"Wygenerowano {proj_dir.name} z {len(swift_files)} plikami Swift:")
    for f in swift_files:
        print(f"  - {f}")


if __name__ == "__main__":
    main()
