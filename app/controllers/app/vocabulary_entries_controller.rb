module App
  # Screen 03. The Vocabulary tab: every word the user has saved, across all
  # the languages they are learning, plus the words they typed in themselves.
  #
  # A word is saved as a *span inside a phrase*, never as a bare dictionary
  # entry, so every screen here shows the phrase with the span highlighted and
  # edits the translation of that span only. "Stop practising" and "Delete" are
  # deliberately different actions: the first is reversible from the list, the
  # second asks first and leaves an undo behind.
  class VocabularyEntriesController < BaseController
    PAUSED_FILTER = "paused".freeze

    # The native Vocabulary tab. VocabularyEntriesController inherits these
    # actions for the web route; each controller's own route and view prefix
    # determine its presentation.
    before_action :set_entry, only: [ :show, :update, :destroy ]

    def index
      @query = params[:q].to_s.strip
      @filter = params[:filter].presence
      @entries = PhraseTokenUser.with_sources(saved_rows.to_a)
      @languages = filter_languages(@entries)
      @total_count = @entries.size
      @paused_count = @entries.count(&:paused?)
      @filter = nil unless filter_available?
      @visible = filtered(@entries)
    end

    def show
      @entry = PhraseTokenUser.with_sources([ @record ]).first
    end

    def update
      if params.key?(:practicing)
        @record.update!(practicing: ActiveModel::Type::Boolean.new.cast(params[:practicing]))
        @entry = @record

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to vocabulary_index_path, notice: notice_for_update }
        end
        return
      end

      translation = params[:translation].to_s.strip

      if translation.present? && (row = @record.token_translation)
        row.update!(translation: translation)
      end

      redirect_to vocabulary_index_path, notice: notice_for_update
    end

    def destroy
      # Only the user's link to the token is removed. The phrase and token stay,
      # which is what makes Undo a plain re-save rather than a resurrection —
      # and for a shared course word they were never this user's to delete.
      word = @record.word
      token_id = @record.phrase_token_id
      language_id = @record.language_id
      @record.destroy!

      redirect_to vocabulary_index_path,
        notice: "“#{word}” deleted",
        flash: { undo: { "phrase_token_id" => token_id, "language_id" => language_id, "word" => word } }
    end

    # The Undo behind the delete toast.
    def restore
      token = PhraseToken.find(params[:phrase_token_id])
      current_user.phrase_token_users.create_with(language_id: params[:language_id])
        .find_or_create_by!(phrase_token: token)

      redirect_to vocabulary_index_path, notice: "Word restored"
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
      redirect_to vocabulary_index_path
    end

    def new
      @sentence = params[:sentence].to_s
      @language_choices = language_choices
      @language = @language_choices.first
    end

    def create
      @language_choices = language_choices
      @language = @language_choices.find { |row| row.iso_name == params[:language] } || @language_choices.first
      @sentence = params[:sentence].to_s

      PhraseTokenUser.create_custom!(
        user: current_user,
        sentence: @sentence,
        language: @language,
        token_range: token_range,
        translation: params[:translation]
      )

      redirect_to vocabulary_index_path, notice: "“#{params[:word].presence || 'Word'}” added"
    rescue PhraseTokenUser::InputError => error
      render_create_error(I18n.t!(error.code, scope: "app.vocabulary_entries.new.errors"))
    rescue PhraseTokenUser::InvalidInput, ActiveRecord::RecordInvalid
      render_create_error(I18n.t!("app.vocabulary_entries.new.errors.save_failed"))
    end

    private

    def vocabulary_index_path
      app_vocabulary_entries_path
    end

    def render_create_error(message)
      @error = message
      render :new, status: :unprocessable_entity
    end

    def set_entry
      @record = saved_rows.find(params[:id])
    end

    def saved_rows
      current_user.phrase_token_users
        .includes(:language, phrase_token: [ :token_translations, { phrase: [ :l1, :medium, :user ] } ])
        .order(created_at: :desc, id: :desc)
    end

    def token_range
      first_index = params[:token_start].presence&.to_i
      last_index = params[:token_end].presence&.to_i || first_index
      return nil if first_index.nil?

      Range.new(*[ first_index, last_index ].minmax)
    end

    def filtered(entries)
      scoped = case @filter
      when nil then entries
      when PAUSED_FILTER then entries.select(&:paused?)
      else entries.select { |entry| entry.source_language&.iso_name == @filter }
      end
      return scoped if @query.blank?

      needle = @query.downcase
      scoped.select { |entry| entry.searchable.include?(needle) }
    end

    # Only languages the user actually has words in get a chip — a filter that
    # can only ever return nothing is noise.
    def filter_languages(entries)
      entries.filter_map(&:source_language).uniq.sort_by { |language| language.english_name.to_s }
    end

    def filter_available?
      return true if @filter.nil?
      return @paused_count.positive? if @filter == PAUSED_FILTER

      @languages.any? { |language| language.iso_name == @filter }
    end

    # What the Add screen offers as the phrase's language: what this user is
    # already learning, falling back to every language the platform has courses
    # in for an account with no vocabulary and no enrollments yet.
    def language_choices
      own = Language.where(id: own_language_ids).order(:english_name).to_a
      return own if own.any?

      # A brand-new account has nothing to infer from. Fall back to what the
      # platform teaches, and past that to every language there is — this list
      # must never come back empty, or the Add screen has no language to save
      # against and every attempt fails on a field the user cannot see.
      taught = Language.where(id: Course.where.not(language_id: nil).select(:language_id)).order(:english_name).to_a
      taught.presence || Language.order(:english_name).to_a
    end

    def own_language_ids
      from_vocabulary = Phrase.joins(phrase_tokens: :phrase_token_users)
        .where(phrase_token_users: { user_id: current_user.id }).select(:l1_id)
      from_courses = Course.joins(:enrollments)
        .where(enrollments: { user_id: current_user.id }).where.not(language_id: nil).select(:language_id)

      Language.where(id: from_vocabulary).or(Language.where(id: from_courses)).select(:id)
    end

    def notice_for_update
      return "Translation saved" unless @record.saved_change_to_practicing?

      @record.practicing? ? "Practice resumed" : "Stopped practising — word kept in your list"
    end
  end
end
