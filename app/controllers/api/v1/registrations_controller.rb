class Api::V1::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      # Generate JWT token for the new user
      token = Warden::JWTAuth::UserEncoder.new.call(resource, :user, nil).first
      render json: {
        success: true,
        message: 'Signed up successfully.',
        data: {
          user: {
            id: resource.id,
            email: resource.email,
            created_at: resource.created_at
          },
          token: token
        }
      }
    else
      render json: {
        success: false,
        message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}"
      }, status: :unprocessable_entity
    end
  end
end
