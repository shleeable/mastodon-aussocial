# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Paperclip::AttachmentExtensions do
  describe '#flush_writes' do
    let(:instance) { double('model_instance', run_paperclip_callbacks: nil, errors: double(any?: false)) }
    let(:attachment) { Paperclip::Attachment.new(:avatar, instance, storage: :filesystem) }
    let(:tempfile) { Tempfile.new('test') }

    before do
      # Avoid missing validator/accessor errors on assign/initialization
      allow(attachment).to receive(:ensure_required_validations!).and_return(nil)
      allow(attachment).to receive(:ensure_required_accessors!).and_return(nil)

      attachment.instance_variable_set(:@queued_for_write, { original: tempfile })
    end

    context 'when flush_writes succeeds' do
      it 'cleans up tempfiles and clears queued writes' do
        expect(attachment).to receive(:after_flush_writes).and_call_original
        attachment.flush_writes
        expect(attachment.queued_for_write).to eq({})
      end
    end

    context 'when flush_writes raises an exception' do
      before do
        allow(attachment.queued_for_write).to receive(:each).and_raise(StandardError, 'Upload failed')
      end

      it 'still cleans up tempfiles and clears queued writes' do
        expect(attachment).to receive(:after_flush_writes).and_call_original

        expect { attachment.flush_writes }.to raise_error(StandardError, 'Upload failed')
        expect(attachment.queued_for_write).to eq({})
      end
    end
  end
end
