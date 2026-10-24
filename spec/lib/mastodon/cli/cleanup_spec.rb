# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/cleanup'

RSpec.describe Mastodon::CLI::Cleanup do
  subject { cli.invoke(action, arguments, options) }

  let(:cli) { described_class.new }
  let(:arguments) { [] }
  let(:options) { {} }

  it_behaves_like 'CLI Command'

  def stub_parallelize_with_progress!
    allow(cli).to receive(:parallelize_with_progress) do |scope, &block|
      aggregate = 0
      total = 0

      scope.reorder(nil).find_each do |record|
        value = block.call(record)
        aggregate += value if value.is_a?(Integer)
        total += 1
      end

      [total, aggregate]
    end
  end

  describe '#accounts' do
    let(:action) { :accounts }
    let(:delete_account_service) { instance_double(DeleteAccountService, call: nil) }

    before do
      allow(DeleteAccountService).to receive(:new).and_return(delete_account_service)
      stub_parallelize_with_progress!
    end

    context 'when no option is given' do
      it 'exits with an error message' do
        expect { subject }
          .to raise_error(Thor::Error, /Please specify at least one cleanup category/)
      end
    end

    context 'with category options' do
      let!(:local_suspended) { Fabricate(:account, domain: nil, suspended_at: 1.day.ago) }
      let!(:remote_suspended) { Fabricate(:account, domain: 'suspended-user.com', suspended_at: 1.day.ago) }
      let!(:local_deleted) { Fabricate(:account, domain: nil, requested_deletion_at: 1.day.ago) }
      let!(:domain_block) { Fabricate(:domain_block, domain: 'suspended-instance.com', severity: :suspend) }
      let!(:account_on_suspended_instance) { Fabricate(:account, domain: 'suspended-instance.com') }
      let!(:active_local_account) { Fabricate(:account, domain: nil) }
      let!(:active_remote_account) { Fabricate(:account, domain: 'active-instance.com') }

      context 'with --local-suspended' do
        let(:options) { { local_suspended: true } }

        it 'deletes local suspended accounts only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts')

          expect(delete_account_service).to have_received(:call).with(local_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(remote_suspended, any_args)
          expect(delete_account_service).to_not have_received(:call).with(local_deleted, any_args)
          expect(delete_account_service).to_not have_received(:call).with(account_on_suspended_instance, any_args)
        end
      end

      context 'with --remote-suspended' do
        let(:options) { { remote_suspended: true } }

        it 'deletes remote suspended accounts only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts')

          expect(delete_account_service).to have_received(:call).with(remote_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(local_suspended, any_args)
        end
      end

      context 'with --local-deleted' do
        let(:options) { { local_deleted: true } }

        it 'deletes local deleted accounts only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts')

          expect(delete_account_service).to have_received(:call).with(local_deleted, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(local_suspended, any_args)
        end
      end

      context 'with --suspended-instances' do
        let(:options) { { suspended_instances: true } }

        it 'deletes accounts on suspended instances only and keeps domain block intact' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts')

          expect(delete_account_service).to have_received(:call).with(account_on_suspended_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(DomainBlock.exists?(id: domain_block.id)).to be(true)
        end
      end

      context 'with --all' do
        let(:options) { { all: true } }

        it 'deletes all matching accounts' do
          expect { subject }
            .to output_results('OK, cleaned up 4 accounts')

          expect(delete_account_service).to have_received(:call).with(local_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(remote_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(local_deleted, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(account_on_suspended_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(active_local_account, any_args)
          expect(delete_account_service).to_not have_received(:call).with(active_remote_account, any_args)
        end

        context 'with --dry-run option' do
          let(:options) { { all: true, dry_run: true } }

          it 'outputs dry run results and does not delete accounts' do
            expect { subject }
              .to output_results('OK, cleaned up 4 accounts (DRY RUN)')

            expect(delete_account_service).to_not have_received(:call)
          end
        end
      end
    end
  end
end
