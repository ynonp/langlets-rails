module Api::V1::Native
  class NotificationsController < BaseController
    def index
      render json: page(user.notifications.order(created_at: :desc, id: :desc)) { |row|
        { id: row.id, title: row.title, body: row.body, url: row.url, read: row.read_at.present?, created_at: row.created_at.iso8601 }
      }
    end
  end
end
