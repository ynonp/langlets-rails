class ProspectMailer < ApplicationMailer
  def invitation
    @prospect = params[:prospect]
    I18n.with_locale(@prospect.locale) do
      url_options = { protocol: Rails.env.production? ? "https" : "http" }
      @setup_url = if @prospect.activated_at?
        new_user_session_url(**url_options)
      else
        marketing_setup_url(token: @prospect.generate_token_for(:setup), **url_options)
      end
      mail to: @prospect.email, subject: t("marketing.email_subject")
    end
  end

  def signup
    @prospect = params[:prospect]
    mail to: User::ADMIN_EMAIL, subject: "Wow! Someone signed up for Langlets Pro"
  end
end
