require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'

root = File.expand_path(ARGV.fetch(0, '..'), __dir__)
workflow = YAML.load_file(File.join(root, '.github/workflows/release.yml'))
steps = workflow.fetch('jobs').fetch('release').fetch('steps')
gate = steps.fetch(1).fetch('run')
publish = steps.find { |s| s['name'] == 'Create or update tag-scoped release' }.fetch('run')
raise 'Version gate must run before setup or builds' unless steps[1]['id'] == 'meta'

Dir.mktmpdir('configforge-release-') do |tmp|
  FileUtils.mkdir_p(File.join(tmp, 'ConfigForge'))
  FileUtils.cp(File.join(root, 'ConfigForge/Info.plist'), File.join(tmp, 'ConfigForge/Info.plist'))
  File.write(File.join(tmp, 'git'), "#!/bin/bash\nif [[ \"$*\" == *refs/tags* && \"${WRONG_COMMIT:-}\" == true ]]; then echo other; else echo commit; fi\n")
  File.write(File.join(tmp, 'gh'), <<~'SH')
    #!/bin/bash
    set -eu
    ruby -rjson -e 'File.open(ENV.fetch("GH_TRACE"), "a") { |f| f.puts(JSON.generate(ARGV)) }' -- "$@"
    if [[ "$2" == view ]]; then
      case "$GH_STATE" in
        missing) exit 1 ;;
        draft) echo true ;;
        published) echo false ;;
      esac
    fi
  SH
  FileUtils.chmod(0755, [File.join(tmp, 'git'), File.join(tmp, 'gh')])
  env = {'PATH' => "#{tmp}:#{ENV.fetch('PATH')}", 'GITHUB_ENV' => File.join(tmp, 'env'), 'GH_TRACE' => File.join(tmp, 'trace'), 'GH_TOKEN' => nil, 'GITHUB_TOKEN' => nil}
  core, status = Open3.capture2('/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleShortVersionString', File.join(tmp, 'ConfigForge/Info.plist'))
  raise 'Cannot read version' unless status.success?
  core = core.strip
  ["v#{core}", "v#{core}-alpha.1", "v#{core}-beta.2", "v#{core}-rc.10"].each do |tag|
    output, status = Open3.capture2e(env.merge('RELEASE_TAG' => tag), 'bash', '-c', gate, chdir: tmp)
    raise "Valid tag failed: #{tag}: #{output}" unless status.success?
    raise 'Wrong version output' unless File.readlines(env['GITHUB_ENV']).last.strip == "VERSION=#{tag.delete_prefix('v')}"
  end
  ['v0.1.0-fix.1', 'v01.2.0', "v#{core}-rc.0", "v#{core}-rc.01", 'v999.0.0', 'develop', 'v1.2', 'v1.2.3+build'].each do |tag|
    _, status = Open3.capture2e(env.merge('RELEASE_TAG' => tag), 'bash', '-c', gate, chdir: tmp)
    raise "Invalid or mismatched tag passed: #{tag}" if status.success?
  end
  _, status = Open3.capture2e(env.merge('RELEASE_TAG' => "v#{core}", 'WRONG_COMMIT' => 'true'), 'bash', '-c', gate, chdir: tmp)
  raise 'Wrong commit passed' if status.success?
  puts 'PASS: SemVer, plist parity, and tag commit gate (positive and negative inputs)'

  ["v#{core}", "v#{core}-alpha.1", "v#{core}-beta.2", "v#{core}-rc.10"].product(%w[missing draft published]).each do |tag, state|
    File.write(env['GH_TRACE'], '')
    _, status = Open3.capture2e(env.merge('RELEASE_TAG' => tag, 'VERSION' => tag.delete_prefix('v'), 'GH_STATE' => state), 'bash', '-c', publish, chdir: tmp)
    calls = File.readlines(env['GH_TRACE']).map { |line| JSON.parse(line) }
    raise 'Release lookup is not tag-scoped' unless calls.first[0..2] == ['release', 'view', tag]
    if state == 'published'
      raise 'Published release was modified' if status.success? || calls.length != 1
      next
    end
    raise "Publish branch failed: #{tag} #{state}" unless status.success?
    raise 'Release call changed target' unless calls.all? { |c| c[0] == 'release' && c[2] == tag }
    final = calls.last
    raise 'Wrong release operation' unless final[1] == (state == 'draft' ? 'edit' : 'create')
    if tag.include?('-')
      raise 'Prerelease flag leaked into stable channel' unless final.include?('--prerelease') && final.include?('--latest=false') && !final.include?('--latest')
    else
      raise 'Stable flags are incorrect' unless final.include?('--prerelease=false') && final.include?('--latest')
    end
    assets = calls.find { |c| %w[create upload].include?(c[1]) }
    %w[x86_64 arm64].each do |arch|
      raise 'Unversioned release asset' unless assets.include?("build/ConfigForge-#{tag.delete_prefix('v')}-#{arch}.dmg")
    end
  end
  puts 'PASS: tag-scoped create/draft/published handling and prerelease channel isolation'
end

%w[0.2.1 0.2.2-rc.1].each do |version|
  output, status = Open3.capture2e('make', '-n', 'dmg', "VERSION=#{version}", chdir: root)
  raise 'Make dry run failed' unless status.success?
  %w[x86_64 arm64].each do |arch|
    raise 'Unversioned DMG output' unless output.include?("\"build/ConfigForge-#{version}-#{arch}.dmg\"")
  end
end
raise 'Legacy Homebrew workflow remains' if File.exist?(File.join(root, '.github/workflows/update-homebrew.yml'))
raise 'Release mutates tags or dispatches Homebrew' if File.read(File.join(root, '.github/workflows/release.yml')).match?(/git tag|git push|repository-dispatch|gh release list/)
puts 'PASS: versioned Makefile DMGs and retired legacy release mutations'
