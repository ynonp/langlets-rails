# frozen_string_literal: true

module HotwireNative
  class ConfigurationsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def show
      render json: {
        settings: {},
        rules: [
          {
            patterns: ["/.*"],
            properties: { context: "default" }
          }
        ]
      }
    end
  end
end
