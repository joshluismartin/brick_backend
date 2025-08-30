class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json
  skip_before_action :verify_signed_out_user, only: [:create]

  def create
    user = User.find_by(email: params[:user][:email])
    
    if user&.valid_password?(params[:user][:password])
      sign_in(user)
      token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      render json: {
        success: true,
        message: 'Logged in successfully.',
        data: {
          user: {
            id: user.id,
            email: user.email,
            created_at: user.created_at
          },
          token: token
        }
      }
    else
      render json: {
        success: false,
        message: 'Invalid email or password.'
      }, status: :unauthorized
    end
  end

  def destroy
    # Simple logout without JWT verification
    sign_out(current_user) if current_user
    render json: { 
      success: true,
      message: 'Logged out successfully' 
    }, status: :ok
  end

  def respond_to_on_destroy
    # Override Devise's respond_to_on_destroy to avoid respond_to method error
    render json: { 
      success: true,
      message: 'Logged out successfully' 
    }, status: :ok
  end

  private

  def respond_with(resource, _opts = {})
    token = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil).first
    render json: {
      success: true,
      message: 'Logged in successfully.',
      data: {
        user: {
          id: resource.id,
          email: resource.email,
          created_at: resource.created_at
        },
        token: token
      }
    }
  end
end
