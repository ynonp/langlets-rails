require "test_helper"

class BetaWelcomeTest < ActionMailer::TestCase
  test "welcome confirmation email explains beta imports in each supported translation" do
    user = User.new(email: "beta-mail@example.test")
    User.stub(:beta_pro?, true) do
      %i[en he es].each do |locale|
        I18n.with_locale(locale) do
          mail = UsersMailer.confirmation_instructions(user, "confirmation-token")
          body = Nokogiri::HTML(mail.body.decoded).text
          assert_includes body, I18n.t("beta_pro.title")
          assert_includes body, I18n.t("beta_pro.body")
          assert_includes mail.body.decoded, "confirmation_token=confirmation-token"
        end
      end
    end
  end

  test "welcome email does not promise beta access after beta ends" do
    mail = UsersMailer.confirmation_instructions(User.new(email: "closed-beta@example.test"), "token")
    assert_not_includes mail.body.decoded, "unlimited imports"
  end
end
