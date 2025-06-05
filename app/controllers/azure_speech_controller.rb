class AzureSpeechController < ApplicationController
  def token
    subscription_key = Rails.application.credentials.azure.tts[:key]
    region = Rails.application.credentials.azure.tts[:region]

    uri = URI("https://#{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken")

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Post.new(uri)
      req['Ocp-Apim-Subscription-Key'] = subscription_key
      http.request(req)
    end

    if response.is_a?(Net::HTTPSuccess)
      render json: { token: response.body, region: region }
    else
      render json: { error: 'Failed to get token' }, status: 500
    end
  end
end