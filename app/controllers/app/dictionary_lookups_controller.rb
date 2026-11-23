module App
  # The Dictionary at the top of the Vocabulary tab. A lookup is created from
  # the tab's input and pushed as its own screen; that screen polls the card
  # partial while the text and then the illustration are generated, and offers
  # Done (back to the tab) or Save to vocabulary.
  class DictionaryLookupsController < BaseController
    include DictionaryTargetLanguage

    before_action :set_lookup, only: [ :show, :card, :save, :illustrate ]

    def create
      target = dictionary_target_language
      return redirect_to(app_vocabulary_entries_path) if target.nil?

      query = params[:query].to_s.split.join(" ")
      return redirect_to(app_vocabulary_entries_path, status: :see_other) if query.empty?

      lookup = current_user.dictionary_lookups.create!(
        query: query.first(DictionaryLookup::MAX_QUERY_LENGTH),
        target_language: target,
        native_language: Current.translation_language
      )
      track_event("dictionary_lookup", language: target.iso_name)

      redirect_to app_vocabulary_dictionary_lookup_path(lookup), status: :see_other
    end

    def show
      @saved = @lookup.saved?
    end

    # The polled card. Renders only the turbo-frame the show page replaces.
    def card
      render partial: "card", locals: { lookup: @lookup }
    end

    def save
      entry = @lookup.save_to_vocabulary!
      newly_saved = entry.previously_new_record?
      track_event("dictionary_word_saved", language: @lookup.target_language.iso_name) if newly_saved

      if newly_saved
        flash[:notice] = t("app.dictionary.saved", word: entry.word)
        flash[:dictionary_undo_entry_id] = entry.id
      end

      redirect_to app_vocabulary_dictionary_lookup_path(@lookup), status: :see_other
    rescue ActiveRecord::RecordInvalid, PhraseTokenUser::InvalidInput
      redirect_to app_vocabulary_dictionary_lookup_path(@lookup), status: :see_other,
        alert: t("app.dictionary.save_failed")
    end

    # "Regenerate illustration".
    def illustrate
      if @lookup.ready? && !@lookup.illustration_drawing?
        @lookup.illustration.purge_later if @lookup.illustration.attached?
        @lookup.illustration_drawing!
        IllustrateDictionaryEntryJob.perform_later(@lookup.id)
      end

      redirect_to app_vocabulary_dictionary_lookup_path(@lookup), status: :see_other
    end

    private

    def set_lookup
      @lookup = current_user.dictionary_lookups
        .includes(:target_language, :native_language)
        .find(params[:id])
    end
  end
end
