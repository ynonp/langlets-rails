module VocabularyEntriesHelper
  def highlighted_vocabulary_context(entry, quoted: false,
                                     mark_class: "font-bold not-italic text-app-accent")
    context = [
      entry.before,
      tag.span(entry.mark, class: mark_class),
      entry.after
    ]

    context.unshift("“").push("”") if quoted
    safe_join(context)
  end
end
