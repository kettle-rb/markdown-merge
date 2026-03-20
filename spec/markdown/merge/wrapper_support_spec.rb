# frozen_string_literal: true

RSpec.describe Markdown::Merge::WrapperSupport do
  let(:wrapper_module) do
    stub_const("SpecMarkdownWrapper", Module.new)
  end

  before do
    allow(described_class).to receive(:register_merge_gem!)
  end

  describe ".install!" do
    before do
      described_class.install!(
        wrapper_module: wrapper_module,
        require_prefix: "spec_markdown_wrapper/merge",
        default_freeze_token: "spec-wrapper",
        default_inner_merge_code_blocks: false,
        registry_tag: :spec_markdown_wrapper,
        merger_class: "SpecMarkdownWrapper::SmartMerger",
      )
    end

    it "defines the shared Markdown-family reexports" do
      expect(wrapper_module::FileAligner).to eq(Markdown::Merge::FileAligner)
      expect(wrapper_module::ConflictResolver).to eq(Markdown::Merge::ConflictResolver)
      expect(wrapper_module::MergeResult).to eq(Markdown::Merge::MergeResult)
      expect(wrapper_module::TableMatchAlgorithm).to eq(Markdown::Merge::TableMatchAlgorithm)
      expect(wrapper_module::TableMatchRefiner).to eq(Markdown::Merge::TableMatchRefiner)
      expect(wrapper_module::CodeBlockMerger).to eq(Markdown::Merge::CodeBlockMerger)
      expect(wrapper_module::NodeTypeNormalizer).to eq(Markdown::Merge::NodeTypeNormalizer)
    end

    it "installs wrapper autoloads for the thin wrapper entrypoints" do
      expect(wrapper_module.autoload?(:DebugLogger)).to eq("spec_markdown_wrapper/merge/debug_logger")
      expect(wrapper_module.autoload?(:CommentTracker)).to eq("spec_markdown_wrapper/merge/comment_tracker")
      expect(wrapper_module.autoload?(:FreezeNode)).to eq("spec_markdown_wrapper/merge/freeze_node")
      expect(wrapper_module.autoload?(:FileAnalysis)).to eq("spec_markdown_wrapper/merge/file_analysis")
      expect(wrapper_module.autoload?(:PartialTemplateMerger)).to eq("spec_markdown_wrapper/merge/partial_template_merger")
      expect(wrapper_module.autoload?(:SmartMerger)).to eq("spec_markdown_wrapper/merge/smart_merger")
      expect(wrapper_module.autoload?(:Backend)).to eq("spec_markdown_wrapper/merge/backend")
    end

    it "defines wrapper defaults and backend-loader hook" do
      expect(wrapper_module::DEFAULT_FREEZE_TOKEN).to eq("spec-wrapper")
      expect(wrapper_module::DEFAULT_INNER_MERGE_CODE_BLOCKS).to be false
      expect(wrapper_module).to respond_to(:ensure_backend_loaded!)
    end
  end

  describe ".configure_smart_merger_subclass!" do
    let(:klass) { Class.new(Markdown::Merge::SmartMerger) }

    it "installs backend and parser defaults without local merge logic" do
      described_class.configure_smart_merger_subclass!(
        klass,
        default_backend: :spec_backend,
        default_freeze_token: "spec-wrapper",
        default_inner_merge_code_blocks: false,
        default_parser_options: {smart: true},
      )

      expect(klass.default_backend).to eq(:spec_backend)
      expect(klass.default_freeze_token).to eq("spec-wrapper")
      expect(klass.default_inner_merge_code_blocks).to be false
      expect(klass.default_parser_options).to eq({smart: true})
    end
  end

  describe ".configure_file_analysis_subclass!" do
    let(:klass) { Class.new(Markdown::Merge::FileAnalysis) }

    it "installs backend defaults for wrapper analyses" do
      described_class.configure_file_analysis_subclass!(klass, default_backend: :spec_backend)

      expect(klass.default_backend).to eq(:spec_backend)
    end
  end

  describe ".configure_partial_template_merger_subclass!" do
    let(:klass) { Class.new(Markdown::Merge::PartialTemplateMerger) }

    it "installs the shared wrapper contract for partial-template mergers" do
      described_class.configure_partial_template_merger_subclass!(
        klass,
        default_backend: :spec_backend,
        file_analysis_class: Markdown::Merge::FileAnalysis,
        smart_merger_class: Markdown::Merge::SmartMerger,
      )

      expect(klass.default_backend).to eq(:spec_backend)
      expect(klass.file_analysis_class).to eq(Markdown::Merge::FileAnalysis)
      expect(klass.smart_merger_class).to eq(Markdown::Merge::SmartMerger)
    end
  end
end
