class Api::V1::BaseController < ActionController::API
  # This will be the parent class for all API controllers
  include ActionController::MimeResponds
  include Devise::Controllers::Helpers
  respond_to :json
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render_error('Missing authorization token', :unauthorized) unless token

    begin
      # Use the same secret key that Devise JWT uses
      secret_key = Rails.application.secret_key_base
      decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      user_id = decoded_token[0]['sub']
      @current_user = User.find(user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound => e
      render_error('Invalid or expired token', :unauthorized)
    end
  end

  def current_user
    @current_user
  end
  
  def render_success(data, message = "Success", status = :ok)
    render json: {
      success: true,
      message: message,
      data: data
    }, status: status
  end
  
  def render_error(message, status = :unprocessable_entity)
    render json: {
      success: false,
      message: message
    }, status: status
  end
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
    devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password])
  end
end
