class ApplicationMailer < ActionMailer::Base
  default from: "ynon@mail.langlets.app"
  layout "mailer"

  def default_url_options
    options = super
    return options unless Rails.env.production?

    code = I18n.locale.to_s
    host = User::NATIVE_LANGUAGE_CODES.include?(code) && code != "en" ? "#{code}.langlets.app" : "langlets.app"
    options.merge(host: host, protocol: "https")
  end
end
