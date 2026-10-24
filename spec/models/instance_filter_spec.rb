# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InstanceFilter do
  subject { described_class.new(params) }

  describe '#results' do
    let!(:healthy_instance) { Fabricate(:instance, domain: 'healthy.com') }
    let!(:failing_instance) { Fabricate(:instance, domain: 'failing.com') }
    let!(:unavailable_instance) { Fabricate(:instance, domain: 'unavailable.com') }
    let!(:unavailable_domain) { Fabricate(:unavailable_domain, domain: 'unavailable.com') }

    before do
      allow(DeliveryFailureTracker).to receive(:warning_domains).and_return(['failing.com'])
    end

    context 'with availability = "healthy"' do
      let(:params) { { availability: 'healthy' } }

      it 'returns instances that are neither failing nor unavailable' do
        expect(subject.results).to include(healthy_instance)
        expect(subject.results).to_not include(failing_instance)
        expect(subject.results).to_not include(unavailable_instance)
      end
    end

    context 'with availability = "failing"' do
      let(:params) { { availability: 'failing' } }

      it 'returns failing instances' do
        expect(subject.results).to include(failing_instance)
        expect(subject.results).to_not include(healthy_instance)
        expect(subject.results).to_not include(unavailable_instance)
      end
    end

    context 'with availability = "unavailable"' do
      let(:params) { { availability: 'unavailable' } }

      it 'returns unavailable instances' do
        expect(subject.results).to include(unavailable_instance)
        expect(subject.results).to_not include(healthy_instance)
        expect(subject.results).to_not include(failing_instance)
      end
    end
  end
end
