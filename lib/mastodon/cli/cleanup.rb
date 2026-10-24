# frozen_string_literal: true

require_relative 'base'

module Mastodon::CLI
  class Cleanup < Base
    option :local_suspended, type: :boolean
    option :remote_suspended, type: :boolean
    option :local_deleted, type: :boolean
    option :suspended_instances, type: :boolean
    option :all, type: :boolean
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :dry_run, type: :boolean
    desc 'accounts', 'Clean up suspended and deleted accounts, posts, and media from DB and S3'
    long_desc <<-LONG_DESC
      Clean up accounts and remove all evidence of those accounts, their posts, and their media from DB and S3.

      With the --local-suspended option, all suspended local accounts will be purged.
      With the --remote-suspended option, all suspended remote accounts will be purged.
      With the --local-deleted option, all deleted local accounts will be purged.
      With the --suspended-instances option, all remote accounts from suspended instances will be purged.
      With the --all option, all of the above categories will be purged.
    LONG_DESC
    def accounts
      unless options[:local_suspended] || options[:remote_suspended] || options[:local_deleted] || options[:suspended_instances] || options[:all]
        fail_with_message 'Please specify at least one cleanup category (--local-suspended, --remote-suspended, --local-deleted, --suspended-instances, or --all)'
      end

      scopes = []

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

      combined_scope = scopes.reduce(:or).without_instance_actor

      _, deleted = parallelize_with_progress(combined_scope) do |account|
        DeleteAccountService.new.call(account, reserve_username: false, reserve_email: false, skip_side_effects: true) unless dry_run?
        1
      end

      say("OK, cleaned up #{deleted} accounts#{dry_run_mode_suffix}", :green)
    end
  end
end
