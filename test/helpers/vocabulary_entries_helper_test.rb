require "test_helper"

class VocabularyEntriesHelperTest < ActionView::TestCase
  Entry = Data.define(:before, :mark, :after)

  test "highlights the saved span with the native vocabulary style" do
    entry = Entry.new(before: "no queda ", mark: "tiempo", after: "")

    assert_equal \
      'no queda <span class="font-bold not-italic text-app-accent">tiempo</span>',
      highlighted_vocabulary_context(entry)
  end

  test "can quote the context and customize the highlight style" do
    entry = Entry.new(before: "no queda ", mark: "tiempo", after: " hoy")

    assert_equal \
      '“no queda <span class="web-highlight">tiempo</span> hoy”',
      highlighted_vocabulary_context(entry, quoted: true, mark_class: "web-highlight")
  end

  test "escapes every part of the vocabulary context" do
    entry = Entry.new(before: "<script>", mark: "<b>word</b>", after: "& more")

    assert_equal \
      '&lt;script&gt;<span class="highlight">&lt;b&gt;word&lt;/b&gt;</span>&amp; more',
      highlighted_vocabulary_context(entry, mark_class: "highlight")
  end
end
