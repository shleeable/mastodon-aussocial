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

      scopes = []

      if options[:domain].present?
        target_domain = TagManager.instance.normalize_domain(options[:domain])
        scopes << Account.remote.where(domain: target_domain)
      end

      if options[:local_suspended] || options[:all]
        scopes << Account.local.suspended
      end

      if options[:remote_suspended] || options[:all]
        scopes << Account.remote.suspended
      end

      if options[:local_deleted] || options[:all]
        scopes << Account.local.where.not(requested_deletion_at: nil)
      end

      if options[:suspended_instances] || options[:all]
        scopes << Account.remote.where(domain: DomainBlock.suspend.select(:domain))
      end

      if options[:limited_instances] || options[:all]
        scopes << Account.remote.where(domain: DomainBlock.silence.select(:domain))
      end

      if options[:reject_media_instances] || options[:all]
        scopes << Account.remote.where(domain: DomainBlock.where(reject_media: true).select(:domain))
      end

      if options[:availability_failing] || options[:all]
        scopes << Account.remote.where(domain: DeliveryFailureTracker.warning_domains)
      end

      if options[:availability_unavailable] || options[:all]
        scopes << Account.remote.where(domain: UnavailableDomain.select(:domain))
      end

      combined_scope = scopes.reduce(:or).without_instance_actor

      progress = create_progress_bar(combined_scope.count)
      total_deleted = 0
      total_statuses = 0
      total_media_count = 0
      total_media_bytes = 0

      combined_scope.find_each do |account|
        acct = account.acct
        statuses_count = account.statuses.count
        media_attachments = account.media_attachments
        media_count = media_attachments.count
        media_bytes = media_attachments.sum(MediaAttachment.combined_media_file_size)

        formatted_size = number_to_human_size(media_bytes)

        if dry_run?
          progress.log("Would delete @#{acct}: #{statuses_count} statuses, #{media_count} media attachments (#{formatted_size})")
        else
          begin
            DeleteAccountService.new.call(account, reserve_username: false, reserve_email: false, skip_side_effects: true)
            progress.log(pastel.green("Deleted @#{acct}: #{statuses_count} statuses, #{media_count} media attachments (#{formatted_size})"))
          rescue => e
            progress.log(pastel.red("Failed to delete @#{acct}: #{e.message}"))
            next
          end
        end

        total_deleted += 1
        total_statuses += statuses_count
        total_media_count += media_count
        total_media_bytes += media_bytes
        progress.increment
      end

      progress.finish

      say(
        "OK, cleaned up #{total_deleted} accounts, #{total_statuses} statuses, #{total_media_count} media attachments (approx. #{number_to_human_size(total_media_bytes)})#{dry_run_mode_suffix}",
        :green
      )
    end
  end
end
