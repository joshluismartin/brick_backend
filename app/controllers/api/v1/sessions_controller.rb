class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json
  skip_before_action :verify_signed_out_user, only: [:create]

  def create
    user = User.find_by(email: params[:user][:email])
    
    if user&.valid_password?(params[:user][:password])
      sign_in(user)
      token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      response.headers['Authorization'] = "Bearer #{token}"
      render json: {
        status: { code: 200, message: 'Logged in successfully.' },
        data: UserSerializer.new(user).serializable_hash[:data][:attributes]
      }
    else
      render json: {
        status: { message: 'Invalid email or password.' }
      }, status: :unauthorized
    end
  end

  def destroy
    # Simple logout without JWT verification
    sign_out(current_user) if current_user
    render json: { status: 200, message: 'Logged out successfully' }, status: :ok
  end

  def respond_to_on_destroy
    # Override Devise's respond_to_on_destroy to avoid respond_to method error
    render json: { status: 200, message: 'Logged out successfully' }, status: :ok
  end

  private

  def respond_with(resource, _opts = {})
    render json: {
      status: { code: 200, message: 'Logged in successfully.' },
      data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
    }
  end
end
