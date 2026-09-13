# frozen_string_literal: true

module Expireable
  extend ActiveSupport::Concern

  included do
    scope :expired, -> { where.not(expires_at: nil).where(expires_at: ...Time.now.utc) }

    def expires_in=(interval)
      self.expires_at = interval.present? ? interval.to_i.seconds.from_now : nil
    end

    def expire!
      touch(:expires_at)
    end

    def expired?
      expires? && expires_at < Time.now.utc
    end

    def expires?
      !expires_at.nil?
    end
  end
end
