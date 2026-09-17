import os, uuid

def get_id(name):
    return uuid.uuid5(uuid.NAMESPACE_DNS, f"letters.{name}").hex[:24].upper()

files = [
    # LettersCoreC
    ("LettersCoreC_shim", "LettersApp/Sources/LettersCoreC/shim.c", "sourcecode.c.c", "Sources"),
    ("LettersCoreC_header", "LettersApp/Sources/LettersCoreC/include/letters_core.h", "sourcecode.c.h", "Headers"),
    ("LettersCoreC_modulemap", "LettersApp/Sources/LettersCoreC/include/module.modulemap", "sourcecode.module-map", "Headers"),
    
    # LettersKit
    ("DocumentModel", "LettersApp/Sources/LettersKit/DocumentModel.swift", "sourcecode.swift", "Sources"),
    ("CoreBridge", "LettersApp/Sources/LettersKit/CoreBridge.swift", "sourcecode.swift", "Sources"),
    ("AIGateway", "LettersApp/Sources/LettersKit/AIGateway.swift", "sourcecode.swift", "Sources"),
    ("TranslationService", "LettersApp/Sources/LettersKit/TranslationService.swift", "sourcecode.swift", "Sources"),
    
    # LettersApp (Studio UI)
    ("StudioTheme", "LettersApp/Sources/LettersApp/StudioTheme.swift", "sourcecode.swift", "Sources"),
    ("StudioToolRail", "LettersApp/Sources/LettersApp/StudioToolRail.swift", "sourcecode.swift", "Sources"),
    ("StudioTopBar", "LettersApp/Sources/LettersApp/StudioTopBar.swift", "sourcecode.swift", "Sources"),
    ("StudioPagesNavigator", "LettersApp/Sources/LettersApp/StudioPagesNavigator.swift", "sourcecode.swift", "Sources"),
    ("StudioBottomBar", "LettersApp/Sources/LettersApp/StudioBottomBar.swift", "sourcecode.swift", "Sources"),
    ("StudioInspectorView", "LettersApp/Sources/LettersApp/StudioInspectorView.swift", "sourcecode.swift", "Sources"),
    ("LettersApp_swift", "LettersApp/Sources/LettersApp/LettersApp.swift", "sourcecode.swift", "Sources"),
    ("MainEditorView", "LettersApp/Sources/LettersApp/MainEditorView.swift", "sourcecode.swift", "Sources"),
    ("TextKit2EditorView", "LettersApp/Sources/LettersApp/TextKit2EditorView.swift", "sourcecode.swift", "Sources"),
    ("CommandPaletteView", "LettersApp/Sources/LettersApp/CommandPaletteView.swift", "sourcecode.swift", "Sources"),
    ("FloatingActionMenu", "LettersApp/Sources/LettersApp/FloatingActionMenu.swift", "sourcecode.swift", "Sources"),
    ("SourceManagerView", "LettersApp/Sources/LettersApp/SourceManagerView.swift", "sourcecode.swift", "Sources"),
    ("AssistantSidebarView", "LettersApp/Sources/LettersApp/AssistantSidebarView.swift", "sourcecode.swift", "Sources"),
    ("DocumentOutlineView", "LettersApp/Sources/LettersApp/DocumentOutlineView.swift", "sourcecode.swift", "Sources"),
]

build_files = []
file_refs = []
sources_build_phase = []
main_group_children = []

for name, path, ftype, phase in files:
    fid = get_id(f"ref_{name}")
    bid = get_id(f"build_{name}")
    base = os.path.basename(path)
    file_refs.append(f'\t\t{fid} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{path}"; sourceTree = "<group>"; }};')
    main_group_children.append(f'\t\t\t\t{fid} /* {base} */,')
    if phase == "Sources":
        build_files.append(f'\t\t{bid} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {base} */; }};')
        sources_build_phase.append(f'\t\t\t\t{bid} /* {base} in Sources */,')

proj_obj_id = get_id("project")
target_id = get_id("target_letters")
config_list_target = get_id("config_list_target")
config_list_proj = get_id("config_list_proj")
debug_config_target = get_id("debug_config_target")
release_config_target = get_id("release_config_target")
debug_config_proj = get_id("debug_config_proj")
release_config_proj = get_id("release_config_proj")
sources_phase_id = get_id("sources_phase")
frameworks_phase_id = get_id("frameworks_phase")
main_group_id = get_id("main_group")
products_group_id = get_id("products_group")
app_product_id = get_id("app_product")

build_files_str = "\n".join(build_files)
file_refs_str = "\n".join(file_refs)
sources_build_phase_str = "\n".join(sources_build_phase)
main_group_children_str = "\n".join(main_group_children)

pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_files_str}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs_str}
		{app_product_id} /* Letters.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Letters.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
				{products_group_id} /* Products */,
{main_group_children_str}
			);
			sourceTree = "<group>";
		}};
		{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_product_id} /* Letters.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_id} /* Letters */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_target} /* Build configuration list for PBXNativeTarget "Letters" */;
			buildPhases = (
				{sources_phase_id} /* Sources */,
				{frameworks_phase_id} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Letters;
			productName = Letters;
			productReference = {app_product_id} /* Letters.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_obj_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject "Letters" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_id} /* Letters */,
			);
		}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_build_phase_str}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_config_proj} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
			}};
			name = Debug;
		}};
		{release_config_proj} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 6.0;
			}};
			name = Release;
		}};
		{debug_config_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Letters;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.projectletters.Letters;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_INCLUDE_PATHS = (
					"$(SRCROOT)/LettersApp/Sources/LettersCoreC/include",
				);
				HEADER_SEARCH_PATHS = (
					"$(SRCROOT)/LettersApp/Sources/LettersCoreC/include",
				);
			}};
			name = Debug;
		}};
		{release_config_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Letters;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.projectletters.Letters;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_INCLUDE_PATHS = (
					"$(SRCROOT)/LettersApp/Sources/LettersCoreC/include",
				);
				HEADER_SEARCH_PATHS = (
					"$(SRCROOT)/LettersApp/Sources/LettersCoreC/include",
				);
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_proj} /* Build configuration list for PBXProject "Letters" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_proj} /* Debug */,
				{release_config_proj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_target} /* Build configuration list for PBXNativeTarget "Letters" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config_target} /* Debug */,
				{release_config_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

	}};
	rootObject = {proj_obj_id} /* Project object */;
}}
"""

out_path = "/Users/mpob/Developer/projectletters/macos/Letters.xcodeproj/project.pbxproj"
with open(out_path, "w") as f:
    f.write(pbxproj)
print("Successfully regenerated project.pbxproj at:", out_path)
