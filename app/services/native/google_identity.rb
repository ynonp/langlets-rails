require "net/http"

module Native
  class GoogleIdentity
    # iOS supplies a single-use server authorization code. Do not accept a client
    # email or unverified JWT as identity; the exchange is bound to our client.
    def self.call(code)
      raise ArgumentError, "Missing Google authorization code" if code.blank?
      response = post("https://oauth2.googleapis.com/token", {
        code: code, client_id: Rails.application.credentials.google_client_id,
        client_secret: Rails.application.credentials.google_client_secret,
        redirect_uri: "", grant_type: "authorization_code"
      })
      return unless response["access_token"].present?
      uri = URI("https://www.googleapis.com/oauth2/v2/userinfo")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{response.fetch('access_token')}"
      result = perform(uri, req)
      return unless result["verified_email"] == true && result["email"].present? && result["id"].present?
      OmniAuth::AuthHash.new(provider: "google_oauth2", uid: result["id"], info: { email: result["email"], name: result["name"] })
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error
      nil
    end

    def self.post(url, body)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(body)
      perform(uri, req)
    end

    def self.perform(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        response = http.request(request)
        response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : {}
      end
    end
    private_class_method :post, :perform
  end
end
