require 'rails_helper'
require 'securerandom'

RSpec.describe 'Api::V1::Registrations', type: :request do
  let(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  describe 'POST /api/v1/signup' do
    it 'returns 200 and user data when valid' do
      email = "spec_user_#{SecureRandom.hex(4)}@example.com"
      params = { user: { email: email, password: 'Secret123!', password_confirmation: 'Secret123!' } }

      post '/api/v1/signup', params: params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig('status', 'code')).to eq(200)
      expect(body.dig('status', 'message')).to eq('Signed up successfully.')
      expect(body.dig('data', 'email')).to eq(email)
    end

    it "returns 422 when user can't be created" do
      params = { user: { email: '', password: 'Secret123!', password_confirmation: 'Secret123!' } }

      post '/api/v1/signup', params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body.dig('status', 'message')).to include("User couldn't be created successfully")
    end
  end
end
