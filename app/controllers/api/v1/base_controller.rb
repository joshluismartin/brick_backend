class Api::V1::BaseController < ApplicationController
  # This will be the parent class for all API controllers
  respond_to :json
  
  private
  
  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end
  
  def render_success(data, message = 'Success')
    render json: { message: message, data: data }, status: :ok
  end
end
