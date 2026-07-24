module Apple
  class AppAccountToken
    def self.for(user)
      digest = OpenSSL::HMAC.digest("SHA256", Rails.application.secret_key_base, "apple-iap-user:#{user.id}")
      bytes = digest.first(16)
      bytes[6] = (bytes[6].ord & 0x0f | 0x40).chr
      bytes[8] = (bytes[8].ord & 0x3f | 0x80).chr
      hex = bytes.unpack1("H*")
      [ hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12] ].join("-")
    end
  end
end
