# The browser Vocabulary surface. Domain behavior lives in the native
# controller and is inherited here; the distinct controller identity gives
# Rails the web templates and layout without inspecting the user agent.
class VocabularyEntriesController < App::VocabularyEntriesController
  skip_before_action :require_native_app
  skip_before_action :set_queue_badge_count

  layout "web"

  private

  def vocabulary_index_path
    vocabulary_entries_path
  end
end
