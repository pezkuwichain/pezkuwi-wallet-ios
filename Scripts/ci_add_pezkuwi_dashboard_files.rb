#!/usr/bin/env ruby
# One-off fix: the PezkuwiDashboard feature's new Swift files were written to disk
# but never added to novawallet.xcodeproj (no PBXFileReference/PBXBuildFile entries),
# so Xcode's build system can't see them ("cannot find type X in scope" for everything
# they define). This adds them to the project and to the 'novawallet' target's Sources
# build phase, mirroring the on-disk folder structure as Xcode groups.
require 'xcodeproj'

project_path = 'novawallet.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'novawallet' }
raise "target 'novawallet' not found" unless target

# path relative to novawallet.xcodeproj's directory (i.e. starts with 'novawallet/...')
new_files = [
  'novawallet/Common/Services/PezkuwiDashboard/PezkuwiDashboardData.swift',
  'novawallet/Common/Services/PezkuwiDashboard/PezkuwiDashboardRepository.swift',
  'novawallet/Modules/AssetList/View/PezkuwiDashboardContainerCollectionViewCell.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardInteractor.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardPresenter.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardProtocols.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardViewFactory.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardViewModel.swift',
  'novawallet/Modules/PezkuwiDashboard/PezkuwiDashboardWireframe.swift',
  'novawallet/Modules/PezkuwiDashboard/View/PezkuwiDashboardCardView.swift',
  'novawallet/Modules/PezkuwiDashboard/View/PezkuwiDashboardMeasurement.swift',
  'novawallet/Modules/PezkuwiDashboard/View/PezkuwiDashboardRoleTagsView.swift',
  'novawallet/Modules/PezkuwiDashboard/View/PezkuwiDashboardViewController.swift'
]

# Finds (or creates) a nested group by a path array relative to the project's main group,
# e.g. ['novawallet', 'Modules', 'PezkuwiDashboard', 'View']
def find_or_create_group(project, path_parts)
  group = project.main_group
  path_parts.each do |part|
    next_group = group.groups.find { |g| g.display_name == part || g.path == part }
    if next_group.nil?
      next_group = group.new_group(part, part)
    end
    group = next_group
  end
  group
end

added = []
skipped = []

new_files.each do |rel_path|
  parts = rel_path.split('/')
  file_name = parts.pop
  group = find_or_create_group(project, parts)

  existing = group.files.find { |f| f.display_name == file_name }
  if existing
    skipped << rel_path
    next
  end

  file_ref = group.new_reference(file_name)
  target.add_file_references([file_ref])
  added << rel_path
end

project.save

puts "Added #{added.length} file(s):"
added.each { |f| puts "  + #{f}" }
puts "Skipped (already present) #{skipped.length} file(s):"
skipped.each { |f| puts "  = #{f}" }
