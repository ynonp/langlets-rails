# Keep account email links on the same language host as the translated message.
class UsersMailer < Devise::Mailer
  def default_url_options
    options = super
    return options unless Rails.env.production?

    code = I18n.locale.to_s
    host = User::NATIVE_LANGUAGE_CODES.include?(code) && code != "en" ? "#{code}.langlets.app" : "langlets.app"
    options.merge(host: host, protocol: "https")
  end
end
