class TokenTranslationUsersController < ApplicationController
  before_action :authenticate_user!

  def index
    response.headers["Cache-Control"] = "private, no-store"
    render json: { token_ids: current_user.saved_phrase_tokens.pluck(:id) }
  end

  def create
    token_translation_id = params[:token_translation_id].to_i
    record = current_user.phrase_token_users.find_or_initialize_by(phrase_token_id: token_translation_id)
    record.language = Current.translation_language
    record.save!
    track_event("word_saved", phrase_token_id: token_translation_id) if record.previously_new_record?
    render json: { saved: true, token_translation_id: token_translation_id }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    render json: { saved: true, token_translation_id: token_translation_id }
  end

  def destroy
    token_translation_id = params[:id].to_i
    removed = current_user.phrase_token_users.where(phrase_token_id: token_translation_id).destroy_all
    track_event("word_removed", phrase_token_id: token_translation_id) if removed.any?
    render json: { saved: false, token_translation_id: token_translation_id }
  end
end
