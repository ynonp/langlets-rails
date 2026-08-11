# Preview at http://localhost:3000/rails/mailers/import_failure_mailer
class ImportFailureMailerPreview < ActionMailer::Preview
  def failed
    ImportFailureMailer.failed(ImportRequest.failed.order(created_at: :desc).first)
  end
end
