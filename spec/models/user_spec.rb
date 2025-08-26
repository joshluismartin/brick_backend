require 'rails_helper'

RSpec.describe User, type: :model do
  it 'is valid with email and password' do
    user = User.new(email: 'ok@example.com', password: 'Secret123!')
    expect(user).to be_valid
  end

  it 'is invalid without email' do
    user = User.new(password: 'Secret123!')
    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it 'jwt_subject returns the user id' do
    user = User.create!(email: 'subj@example.com', password: 'Secret123!')
    expect(user.jwt_subject).to eq(user.id)
  end
end