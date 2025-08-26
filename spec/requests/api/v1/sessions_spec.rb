require 'rails_helper'

RSpec.describe 'Api::V1::Sessions', type: :request do
  let(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  before do
    User.create!(email: 'me@example.com', password: 'Secret123!')
  end

  describe 'POST /api/v1/login' do
    it 'logs in successfully and sets Authorization header' do
      params = { user: { email: 'me@example.com', password: 'Secret123!' } }

      post '/api/v1/login', params: params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['Authorization']).to match(/^Bearer /)

      body = JSON.parse(response.body)
      expect(body.dig('status', 'code')).to eq(200)
      expect(body.dig('status', 'message')).to eq('Logged in successfully.')
      expect(body.dig('data', 'email')).to eq('me@example.com')
    end

    it 'returns 401 for wrong password' do
      params = { user: { email: 'me@example.com', password: 'WRONG' } }

      post '/api/v1/login', params: params.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig('status', 'message')).to eq('Invalid email or password.')
    end
  end

  describe 'DELETE /api/v1/logout' do
    it 'logs out successfully' do
      delete '/api/v1/logout', headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq(200)
      expect(body['message']).to eq('Logged out successfully')
    end
  end
end
