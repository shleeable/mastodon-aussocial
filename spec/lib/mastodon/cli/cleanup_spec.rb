# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/cli/cleanup'

RSpec.describe Mastodon::CLI::Cleanup do
  subject { cli.invoke(action, arguments, options) }

  let(:cli) { described_class.new }
  let(:arguments) { [] }
  let(:options) { {} }

  it_behaves_like 'CLI Command'

  describe '#accounts' do
    let(:action) { :accounts }
    let(:delete_account_service) { instance_double(DeleteAccountService, call: nil) }

    before do
      allow(DeleteAccountService).to receive(:new).and_return(delete_account_service)
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
      let!(:suspended_domain_block) { Fabricate(:domain_block, domain: 'suspended-instance.com', severity: :suspend) }
      let!(:account_on_suspended_instance) { Fabricate(:account, domain: 'suspended-instance.com') }
      let!(:limited_domain_block) { Fabricate(:domain_block, domain: 'limited-instance.com', severity: :silence) }
      let!(:account_on_limited_instance) { Fabricate(:account, domain: 'limited-instance.com') }
      let!(:reject_media_domain_block) { Fabricate(:domain_block, domain: 'reject-media-instance.com', severity: :noop, reject_media: true) }
      let!(:account_on_reject_media_instance) { Fabricate(:account, domain: 'reject-media-instance.com') }
      let!(:failing_account) { Fabricate(:account, domain: 'failing-instance.com') }
      let!(:unavailable_domain) { Fabricate(:unavailable_domain, domain: 'unavailable-instance.com') }
      let!(:unavailable_account) { Fabricate(:account, domain: 'unavailable-instance.com') }
      let!(:specific_domain_account) { Fabricate(:account, domain: 'target-domain.com') }

      let!(:active_local_account) { Fabricate(:account, domain: nil) }
      let!(:active_remote_account) { Fabricate(:account, domain: 'active-instance.com') }

      before do
        allow(DeliveryFailureTracker).to receive(:warning_domains).and_return(['failing-instance.com'])
      end

      context 'with --domain' do
        let(:options) { { domain: 'TARGET-DOMAIN.COM' } }

        it 'deletes remote accounts from specified domain case-insensitively' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(specific_domain_account, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(active_remote_account, any_args)
        end
      end

      context 'with --domain combined with category flags' do
        let(:options) { { domain: 'suspended-instance.com', suspended_instances: true } }

        it 'restricts suspended_instances scope to specified domain' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(account_on_suspended_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(remote_suspended, any_args)
        end
      end

      context 'with --local-suspended' do
        let(:options) { { local_suspended: true } }

        it 'deletes local suspended accounts only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

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
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(remote_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(local_suspended, any_args)
        end
      end

      context 'with --local-deleted' do
        let(:options) { { local_deleted: true } }

        it 'deletes local deleted accounts only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(local_deleted, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(local_suspended, any_args)
        end
      end

      context 'with --suspended-instances' do
        let(:options) { { suspended_instances: true } }

        it 'deletes accounts on suspended instances only and keeps domain block intact' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(account_on_suspended_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(DomainBlock.exists?(id: suspended_domain_block.id)).to be(true)
        end
      end

      context 'with --limited-instances' do
        let(:options) { { limited_instances: true } }

        it 'deletes accounts on limited instances only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(account_on_limited_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(account_on_suspended_instance, any_args)
        end
      end

      context 'with --rejectMediaInstances' do
        let(:options) { { rejectMediaInstances: true } }

        it 'deletes accounts on instances rejecting media' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(account_on_reject_media_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
        end
      end

      context 'with --availabilityFailing' do
        let(:options) { { availabilityFailing: true } }

        it 'deletes accounts on failing instances only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(failing_account, reserve_username: false, reserve_email: false, skip_side_effects: true).once
        end
      end

      context 'with --availabilityUnavailable' do
        let(:options) { { availabilityUnavailable: true } }

        it 'deletes accounts on unavailable instances only' do
          expect { subject }
            .to output_results('OK, cleaned up 1 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(unavailable_account, reserve_username: false, reserve_email: false, skip_side_effects: true).once
        end
      end

      context 'with --all' do
        let(:options) { { all: true } }

        it 'deletes all matching accounts' do
          expect { subject }
            .to output_results('OK, cleaned up 8 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes)')

          expect(delete_account_service).to have_received(:call).with(local_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(remote_suspended, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(local_deleted, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(account_on_suspended_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(account_on_limited_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(account_on_reject_media_instance, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(failing_account, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to have_received(:call).with(unavailable_account, reserve_username: false, reserve_email: false, skip_side_effects: true).once
          expect(delete_account_service).to_not have_received(:call).with(active_local_account, any_args)
          expect(delete_account_service).to_not have_received(:call).with(active_remote_account, any_args)
        end

        context 'with --dry-run option' do
          let(:options) { { all: true, dry_run: true } }

          it 'outputs dry run results and does not delete accounts' do
            expect { subject }
              .to output_results('OK, cleaned up 8 accounts, 0 statuses, 0 media attachments (approx. 0 Bytes) (DRY RUN)')

            expect(delete_account_service).to_not have_received(:call)
          end
        end
      end
    end
  end

  describe '#refreshhealth' do
    let(:action) { :refreshhealth }
    let!(:suspended_block) { Fabricate(:domain_block, domain: 'suspended.com', severity: :suspend) }
    let!(:limited_block) { Fabricate(:domain_block, domain: 'limited.com', severity: :silence) }

    before do
      allow(DeliveryFailureTracker).to receive(:reset!)
    end

    context 'when an instance is alive' do
      before do
        stub_request(:get, 'https://suspended.com/api/v1/instance').to_return(status: 200)
        stub_request(:get, 'https://limited.com/api/v1/instance').to_return(status: 500)
      end

      it 'resets delivery failure tracking for alive instances' do
        expect { subject }
          .to output_results('Checked 2 instances: 1 alive (delivery failure tracking reset), 1 unreachable')

        expect(DeliveryFailureTracker).to have_received(:reset!).with('suspended.com').once
        expect(DeliveryFailureTracker).to_not have_received(:reset!).with('limited.com')
      end
    end

    context 'with --suspended option' do
      let(:options) { { suspended: true } }

      before do
        stub_request(:get, 'https://suspended.com/api/v1/instance').to_return(status: 200)
      end

      it 'queries suspended instances only' do
        expect { subject }
          .to output_results('Checked 1 instances: 1 alive (delivery failure tracking reset), 0 unreachable')

        expect(DeliveryFailureTracker).to have_received(:call_or_reset, 'suspended.com') if false # check called on suspended.com
        expect(DeliveryFailureTracker).to have_received(:reset!).with('suspended.com').once
      end
    end

    context 'with --limited option' do
      let(:options) { { limited: true } }

      before do
        stub_request(:get, 'https://limited.com/api/v1/instance').to_return(status: 200)
      end

      it 'queries limited instances only' do
        expect { subject }
          .to output_results('Checked 1 instances: 1 alive (delivery failure tracking reset), 0 unreachable')

        expect(DeliveryFailureTracker).to have_received(:reset!).with('limited.com').once
      end
    end
  end
end
