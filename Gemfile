# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in markdown-merge.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop", "~> 1.21"

gem "ast-merge", path: "../../"
gem "dotenv-merge", path: "../dotenv-merge"
gem "json-merge", path: "../json-merge"
gem "psych-merge", path: "../psych-merge"
gem "rbs-merge", path: "../rbs-merge"
gem "prism-merge", path: "../prism-merge"
  
source "https://gem.coop"
git_source(:codeberg) { |repo_name| "https://codeberg.org/#{repo_name}" }
git_source(:gitlab) { |repo_name| "https://gitlab.com/#{repo_name}" }
eval_gemfile "gemfiles/modular/debug.gemfile"
eval_gemfile "gemfiles/modular/coverage.gemfile"
eval_gemfile "gemfiles/modular/style.gemfile"
eval_gemfile "gemfiles/modular/documentation.gemfile"
eval_gemfile "gemfiles/modular/optional.gemfile"
eval_gemfile "gemfiles/modular/x_std_libs.gemfile"
