module UserImportFiltering
  extend ActiveSupport::Concern

  IMPORT_FILTERS = %w[pending failed my_imports].freeze

  included do
    # Videos the user has asked to turn into courses (the Queue screen).
    has_many :import_requests, dependent: :destroy
  end

  # Import filters are shared by the web Gallery and native Library. Keeping
  # their meanings here prevents the two surfaces from drifting when a status
  # or filter changes.
  def available_import_filters
    filters = []
    filters << "pending" if import_requests.active.exists?
    filters << "failed" if import_requests.failed.exists?
    filters << "my_imports" if import_requests.where.not(status: :canceled).exists?
    filters
  end

  def import_requests_for_filter(filter)
    case filter
    when "failed" then import_requests.failed
    when "pending", nil then import_requests.active
    when "my_imports" then import_requests.where(status: %i[detecting queued importing failed])
    else import_requests.none
    end
  end

  def ready_imported_course_ids
    import_requests.ready.where.not(course_id: nil).select(:course_id)
  end
end
