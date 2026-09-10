require "test_helper"

class SpanishLocaleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "Spanish host renders Spanish and has a Spanish canonical URL" do
    host! "es.langlets.app"
    https!
    get root_path
    assert_response :success
    assert_select "html[lang=es][dir=ltr]"
    assert_select "h1", text: "Convierte cualquier vídeo en una lección de idiomas"
    assert_select "link[rel=canonical][href='https://es.langlets.app/']"
    assert_select "meta[property='og:locale'][content=es_ES]"
    refute_match(/translation_missing|Translation missing/, response.body)
  end

  test "Spanish native preference controls profile and tab titles on the main host" do
    user = User.create!(email: "spanish-native@example.test", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    patch profile_native_language_path, params: { user: { native_language: "es" } },
      headers: { "User-Agent" => "LangletsNative (Android)" }
    assert_redirected_to profile_path
    assert_equal "es", user.reload.native_language.iso_name
    get profile_path, headers: { "User-Agent" => "LangletsNative (Android)" }
    assert_response :success
    assert_select "html[lang=es][dir=ltr]"
    assert_select "h1", text: "Perfil"
    get app_library_path, headers: { "User-Agent" => "LangletsNative (Android)" }
    assert_response :success
    assert_select "[data-bridge--tab-badge-titles-value]" do |nodes|
      assert_equal [ "Inicio", "Biblioteca", "Vocabulario", "Crear" ], JSON.parse(nodes.first["data-bridge--tab-badge-titles-value"])
    end
    refute_match(/translation_missing|Translation missing/, response.body)
  end

  test "Spanish catalog contains every application key and preserves interpolations" do
    english = catalog("en")
    spanish = catalog("es")
    english.each do |key, value|
      assert spanish.key?(key), "Missing Spanish key: #{key}"
      if value.is_a?(String)
        assert_kind_of String, spanish.fetch(key), "Invalid Spanish value: #{key}"
        assert_equal value.scan(/%\{[^}]+\}/).sort,
          spanish.fetch(key).scan(/%\{[^}]+\}/).sort, "Interpolation mismatch: #{key}"
      end
    end
  end

  test "Spanish signup stores the language and sends a translated confirmation" do
    host! "es.langlets.app"
    assert_difference "User.count", 1 do
      post user_registration_path, params: { user: { email: "spanish-signup@example.test", password: "password123", password_confirmation: "password123" } }
    end
    user = User.find_by!(email: "spanish-signup@example.test")
    assert_equal "es", user.native_language.iso_name
    email = ActionMailer::Base.deliveries.last
    assert_equal "Instrucciones de confirmación", email.subject
    assert_includes email.body.decoded, "Confirmar mi cuenta"
  end

  test "Spanish learner pages and legal documents render without missing translations" do
    host! "es.langlets.app"
    [ gallery_path, new_user_session_path, new_user_registration_path, new_user_password_path,
     new_user_confirmation_path, "/home/privacy", "/home/terms" ].each do |path|
      get path
      assert_response :success
      assert_select "html[lang=es][dir=ltr]"
      refute_match(/translation_missing|Translation missing/, response.body, path)
    end
  end

  test "Spanish prospects and background notifications use Spanish" do
    prospect = Prospect.create!(email: "spanish-prospect@example.test", locale: "es")
    assert_equal "Tu acceso gratuito a Langlets Pro te está esperando", ProspectMailer.with(prospect: prospect).invitation.subject
    user = User.create!(email: "spanish-notifications@example.test", password: "password123", confirmed_at: Time.zone.now, preferences: { native_language: "es" })
    notification = user.notifications.create!(kind: :pro_activated)
    assert_equal "Ya tienes una suscripción Pro", NotificationMailer.notify(notification).subject
    assert_equal "Ya tienes una suscripción Pro", Push::Notifier.new(notification).payload[:alert][:title]
  end

  private

  def catalog(locale)
    translations = {}
    flatten = lambda do |value, path|
      if value.is_a?(Hash)
        value.each { |key, child| flatten.call(child, path + [ key ]) }
      else
        translations[path.join(".")] = value
      end
    end
    Dir[Rails.root.join("config/locales/*.yml")].sort.each do |path|
      data = YAML.load_file(path)[locale]
      flatten.call(data, []) if data
    end
    translations
  end
end
