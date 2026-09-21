require 'xcodeproj'
project_path = 'macos/Letters.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.first

# Add the file to the group
group = project.main_group.find_subpath('LettersApp/Sources/LettersApp', true)
file_ref = group.new_reference('AIThinkingView.swift')

# Add the file to the target's source build phase
target.source_build_phase.add_file_reference(file_ref)

project.save
