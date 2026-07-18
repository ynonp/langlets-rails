class TokenTranslationUsersController < ApplicationController
  before_action :authenticate_user!

  def create
    token_translation_id = params[:token_translation_id].to_i
    record = current_user.phrase_token_users.find_or_initialize_by(phrase_token_id: token_translation_id)
    record.language = Current.translation_language
    record.save!
    render json: { saved: true, token_translation_id: token_translation_id }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    render json: { saved: true, token_translation_id: token_translation_id }
  end

  def destroy
    token_translation_id = params[:id].to_i
    current_user.phrase_token_users.where(phrase_token_id: token_translation_id).delete_all
    render json: { saved: false, token_translation_id: token_translation_id }
  end
end
