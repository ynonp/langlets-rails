module Admin::AdminHelper
  def admin_status(status)
    tone = case status.to_s
    when "ready", "published", "pro" then "success"
    when "failed", "error" then "danger"
    when "importing", "processing", "queued", "detecting" then "pending"
    else "neutral"
    end
    tag.span(status.to_s.humanize, class: "admin-badge #{tone}")
  end

  def admin_time(time)
    time ? time.utc.strftime("%d %b %Y, %H:%M UTC") : "—"
  end
end
