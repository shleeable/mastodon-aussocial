# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polls' do
  let(:user)    { Fabricate(:user) }
  let(:scopes)  { 'read:statuses' }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'GET /api/v1/polls/:id' do
    subject do
      get "/api/v1/polls/#{poll.id}", headers: headers
    end

    let(:poll)       { Fabricate(:poll, status: Fabricate(:status, visibility: visibility)) }
    let(:visibility) { 'public' }

    it_behaves_like 'forbidden for wrong scope', 'write write:statuses'

    context 'when parent status is public' do
      it 'returns the poll data successfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(response.content_type)
          .to start_with('application/json')
        expect(response.parsed_body).to match(
          a_hash_including(
            id: poll.id.to_s,
            voted: false,
            voters_count: poll.voters_count,
            votes_count: poll.votes_count
          )
        )
      end
    end

    context 'when poll is remote and needs refresh' do
      let(:poll) { Fabricate(:poll, last_fetched_at: nil, account: remote_account, status: status) }
      let(:remote_account) { Fabricate :account, domain: 'host.example' }
      let(:service) { instance_double(ActivityPub::FetchRemotePollService, call: nil) }
      let(:status) { Fabricate(:status, visibility: 'public', account: remote_account) }

      before { allow(ActivityPub::FetchRemotePollService).to receive(:new).and_return(service) }

      it 'returns poll data and calls fetch remote service' do
        subject

        expect(response)
          .to have_http_status(200)
        expect(response.content_type)
          .to start_with('application/json')
        expect(response.parsed_body).to match(
          a_hash_including(
            id: poll.id.to_s
          )
        )
        expect(service)
          .to have_received(:call).with(poll, user.account)
      end
    end

    context 'when parent status is private' do
      let(:visibility) { 'private' }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
        expect(response.content_type)
          .to start_with('application/json')
      end
    end
  end
end
