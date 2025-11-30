# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch('MAILER_FROM_EMAIL', 'noreply@example.com') }
  layout 'mailer'
end
