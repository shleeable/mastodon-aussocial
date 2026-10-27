# frozen_string_literal: true

require_relative 'base'

module Mastodon::CLI
  class Cleanup < Base
    include ActionView::Helpers::NumberHelper

    option :domain, type: :string
    option :local_suspended, type: :boolean
    option :remote_suspended, type: :boolean
    option :local_deleted, type: :boolean
    option :suspended_instances, type: :boolean
    option :limited_instances, type: :boolean
    option :reject_media_instances, type: :boolean, aliases: [:rejectMediaInstances]
    option :availability_failing, type: :boolean, aliases: [:availabilityFailing]
    option :availability_unavailable, type: :boolean, aliases: [:availabilityUnavailable]
    option :all, type: :boolean
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :dry_run, type: :boolean
    desc 'accounts', 'Clean up suspended, deleted, limited, domain-specific, or failing accounts, posts, and media from DB and S3'
    long_desc <<-LONG_DESC
      Clean up accounts and remove all evidence of those accounts, their posts, and their media from DB and S3.

      With the --domain DOMAIN option, all remote accounts from a specific domain will be purged.
      With the --local-suspended option, all suspended local accounts will be purged.
      With the --remote-suspended option, all suspended remote accounts will be purged.
      With the --local-deleted option, all deleted local accounts will be purged.
      With the --suspended-instances option, all remote accounts from suspended instances will be purged.
      With the --limited-instances option, all remote accounts from limited/silenced instances will be purged.
      With the --reject-media-instances / --rejectMediaInstances option, all remote accounts from instances rejecting media will be purged.
      With the --availability-failing / --availabilityFailing option, all remote accounts from failing instances will be purged.
      With the --availability-unavailable / --availabilityUnavailable option, all remote accounts from unavailable instances will be purged.
      With the --all option, all of the above categories will be purged.
    LONG_DESC
    def accounts
      unless options[:domain].present? || options[:local_suspended] || options[:remote_suspended] || options[:local_deleted] || options[:suspended_instances] || options[:limited_instances] || options[:reject_media_instances] || options[:availability_failing] || options[:availability_unavailable] || options[:all]
        fail_with_message 'Please specify at least one cleanup category (--domain, --local-suspended, --remote-suspended, --local-deleted, --suspended-instances, --limited-instances, --reject-media-instances, --availability-failing, --availability-unavailable, or --all)'
      end

      target_domain = options[:domain].present? ? TagManager.instance.normalize_domain(options[:domain].to_s.strip) : nil
      scopes = []

      if target_domain.present?
        scopes << Account.remote.with_domain(target_domain)
      end

      if options[:local_suspended] || options[:all]
        scopes << Account.local.suspended
      end

      if options[:remote_suspended] || options[:all]
        scope = Account.remote.suspended
        scope = scope.with_domain(target_domain) if target_domain.present?
        scopes << scope
      end

      if options[:local_deleted] || options[:all]
        scopes << Account.local.where.not(requested_deletion_at: nil)
      end

      if options[:suspended_instances] || options[:all]
        domain_scope = DomainBlock.suspend.select(:domain)
        domain_scope = domain_scope.where('lower(domain) = lower(?)', target_domain) if target_domain.present?
        scopes << Account.remote.where(domain: domain_scope)
      end

      if options[:limited_instances] || options[:all]
        domain_scope = DomainBlock.silence.select(:domain)
        domain_scope = domain_scope.where('lower(domain) = lower(?)', target_domain) if target_domain.present?
        scopes << Account.remote.where(domain: domain_scope)
      end

      if options[:reject_media_instances] || options[:all]
        domain_scope = DomainBlock.where(reject_media: true).select(:domain)
        domain_scope = domain_scope.where('lower(domain) = lower(?)', target_domain) if target_domain.present?
        scopes << Account.remote.where(domain: domain_scope)
      end

      if options[:availability_failing] || options[:all]
        warning_domains = DeliveryFailureTracker.warning_domains
        warning_domains = warning_domains.select { |d| d.casecmp?(target_domain) } if target_domain.present?
        scopes << Account.remote.where(domain: warning_domains)
      end

      if options[:availability_unavailable] || options[:all]
        domain_scope = UnavailableDomain.select(:domain)
        domain_scope = domain_scope.where('lower(domain) = lower(?)', target_domain) if target_domain.present?
        scopes << Account.remote.where(domain: domain_scope)
      end

      combined_scope = scopes.reduce(:or).without_instance_actor

      total_statuses = Concurrent::AtomicFixnum.new(0)
      total_media_count = Concurrent::AtomicFixnum.new(0)
      total_media_bytes = Concurrent::AtomicFixnum.new(0)

      processed, = parallelize_with_progress(combined_scope) do |account|
        acct = account.acct
        statuses_count = account.statuses.count
        media_attachments = account.media_attachments
        media_count = media_attachments.count
        media_bytes = media_attachments.sum(MediaAttachment.combined_media_file_size)

        formatted_size = number_to_human_size(media_bytes)

        if dry_run?
          say("Would delete @#{acct}: #{statuses_count} statuses, #{media_count} media attachments (#{formatted_size})")
        else
          begin
            DeleteAccountService.new.call(account, reserve_username: false, reserve_email: false, skip_side_effects: true)
            say(pastel.green("Deleted @#{acct}: #{statuses_count} statuses, #{media_count} media attachments (#{formatted_size})"))
          rescue => e
            say(pastel.red("Failed to delete @#{acct}: #{e.message}"))
            next
          end
        end

        total_statuses.increment(statuses_count)
        total_media_count.increment(media_count)
        total_media_bytes.increment(media_bytes)
        1
      end

      say(
        "OK, cleaned up #{processed} accounts, #{total_statuses.value} statuses, #{total_media_count.value} media attachments (approx. #{number_to_human_size(total_media_bytes.value)})#{dry_run_mode_suffix}",
        :green
      )
    end

    option :suspended, type: :boolean
    option :limited, type: :boolean
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    desc 'refreshhealth', 'Validate health and clear delivery failure tracking for suspended/limited instances'
    long_desc <<-LONG_DESC
      Query instances on your suspended/limited block list to verify if they are alive and reset delivery failure tracking for healthy instances.

      With the --suspended option, only instances on the suspended block list will be queried.
      With the --limited option, only instances on the limited/silenced block list will be queried.
      If neither flag is specified, both suspended and limited instances will be queried.
    LONG_DESC
    def refreshhealth
      severities = []

      if options[:suspended] || (!options[:suspended] && !options[:limited])
        severities << :suspend
      end

      if options[:limited] || (!options[:suspended] && !options[:limited])
        severities << :silence
      end

      scope = DomainBlock.where(severity: severities)

      processed, alive = parallelize_with_progress(scope) do |domain_block|
        domain = domain_block.domain
        is_alive = false

        begin
          Request.new(:get, "https://#{domain}/api/v1/instance").perform do |res|
            is_alive = (res.code == 200)
          end
        rescue *Mastodon::HTTP_CONNECTION_ERRORS, Mastodon::PrivateNetworkAddressError
          is_alive = false
        end

        if is_alive
          DeliveryFailureTracker.reset!(domain)
          1
        else
          0
        end
      end

      say("Checked #{processed} instances: #{alive} alive (delivery failure tracking reset), #{processed - alive} unreachable", :green)
    end
  end
end
