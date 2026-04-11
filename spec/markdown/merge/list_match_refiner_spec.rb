# frozen_string_literal: true

RSpec.describe Markdown::Merge::ListMatchRefiner do
  subject(:refiner) { described_class.new }

  let(:template) do
    <<~MARKDOWN
      Executables shipped by dependencies, such as {KJ|KETTLE_DEV_GEM}, and stone_checksums, are available
      after running `bin/setup`. These include:

      - gem_checksums
      - kettle-changelog
      - kettle-commit-msg
      - {KJ|KETTLE_DEV_GEM}-setup
      - kettle-dvcs
      - kettle-pre-release
      - kettle-readme-backers
      - kettle-release

      Coverage (kettle-soup-cover / SimpleCov)

      - K_SOUP_COV_DO: Enable coverage collection (default: true in `mise.toml`)
      - K_SOUP_COV_FORMATTERS: Comma-separated list of formatters (html, xml, rcov, lcov, json, tty)
      - K_SOUP_COV_MIN_LINE: Minimum line coverage threshold (integer, e.g., 100)
      - K_SOUP_COV_MIN_BRANCH: Minimum branch coverage threshold (integer, e.g., 100)
      - K_SOUP_COV_MIN_HARD: Fail the run if thresholds are not met (true/false)
      - K_SOUP_COV_MULTI_FORMATTERS: Enable multiple formatters at once (true/false)
      - K_SOUP_COV_OPEN_BIN: Path to browser opener for HTML (empty disables auto-open)
      - MAX_ROWS: Limit console output rows for simplecov-console (e.g., 1)

      Git hooks and commit message helpers (exe/kettle-commit-msg)

      - GIT_HOOK_BRANCH_VALIDATE: Branch name validation mode (e.g., `jira`) or `false` to disable
      - GIT_HOOK_FOOTER_APPEND: Append a footer to commit messages when goalie allows (true/false)
      - GIT_HOOK_FOOTER_SENTINEL: Required when footer append is enabled — a unique first-line sentinel to prevent duplicates
      - GIT_HOOK_FOOTER_APPEND_DEBUG: Extra debug output in the footer template
    MARKDOWN
  end

  let(:destination) do
    <<~MARKDOWN
      Coverage (kettle-soup-cover / SimpleCov)

      ## Executables vs Rake tasks

      Executables shipped by dependencies, such as kettle-dev, and stone_checksums, are available
      after running `bin/setup`. These include:

      - gem_checksums
      - kettle-changelog
      - kettle-commit-msg
      - kettle-dev-setup
      - kettle-dvcs
      - kettle-pre-release
      - kettle-readme-backers
      - kettle-release

      - K_SOUP_COV_DO: Enable coverage collection (default: true in `mise.toml`)
      - K_SOUP_COV_FORMATTERS: Comma-separated list of formatters (html, xml, rcov, lcov, json, tty)
      - K_SOUP_COV_MIN_LINE: Minimum line coverage threshold (integer, e.g., 100)
      - K_SOUP_COV_MIN_BRANCH: Minimum branch coverage threshold (integer, e.g., 100)
      - K_SOUP_COV_MIN_HARD: Fail the run if thresholds are not met (true/false)
      - K_SOUP_COV_MULTI_FORMATTERS: Enable multiple formatters at once (true/false)
      - K_SOUP_COV_OPEN_BIN: Path to browser opener for HTML (empty disables auto-open)
      - MAX_ROWS: Limit console output rows for simplecov-console (e.g., 1)

      Git hooks and commit message helpers (exe/kettle-commit-msg)

      - GIT_HOOK_BRANCH_VALIDATE: Branch name validation mode (e.g., `jira`) or `false` to disable
      - GIT_HOOK_FOOTER_APPEND: Append a footer to commit messages when goalie allows (true/false)
      - GIT_HOOK_FOOTER_SENTINEL: Required when footer append is enabled — a unique first-line sentinel to prevent duplicates
      - GIT_HOOK_FOOTER_APPEND_DEBUG: Extra debug output in the footer template
      - gem_checksums
      - kettle-changelog
      - kettle-commit-msg
      - kettle-dev-setup
      - kettle-dvcs
      - kettle-pre-release
      - kettle-readme-backers
      - kettle-release
      - gem_checksums
      - kettle-changelog
      - kettle-commit-msg
      - kettle-dev-setup
      - kettle-dvcs
      - kettle-pre-release
      - kettle-readme-backers
      - kettle-release
    MARKDOWN
  end

  let(:template_analysis) { Markdown::Merge::FileAnalysis.new(template) }
  let(:dest_analysis) { Markdown::Merge::FileAnalysis.new(destination) }
  let(:context) { {template_analysis: template_analysis, dest_analysis: dest_analysis} }

  it "matches the coverage template list to the executable+coverage corruption block" do
    corrupted_destination_list = dest_analysis.statements.find { |stmt| dest_analysis.signature_at(dest_analysis.statements.index(stmt)) == [:list, nil, 16] }
    coverage_template_list = template_analysis.statements.find { |stmt| stmt.text.include?("K_SOUP_COV_DO") }

    matches = refiner.call(
      [coverage_template_list],
      [corrupted_destination_list],
      context,
    )

    expect(matches.length).to eq(1)
    expect(matches.first.template_node.text).to eq(coverage_template_list.text)
    expect(matches.first.dest_node.text).to eq(corrupted_destination_list.text)
  end

  it "matches the git-hook template list to the oversized corrupted destination list" do
    template_list = template_analysis.statements.find { |stmt| stmt.text.include?("GIT_HOOK_BRANCH_VALIDATE") }
    corrupted_destination_list = dest_analysis.statements.find { |stmt| dest_analysis.signature_at(dest_analysis.statements.index(stmt)) == [:list, nil, 20] }

    matches = refiner.call([template_list], [corrupted_destination_list], context)

    expect(matches.length).to eq(1)
    expect(matches.first.template_node).to equal(template_list)
    expect(matches.first.dest_node).to equal(corrupted_destination_list)
  end
end
