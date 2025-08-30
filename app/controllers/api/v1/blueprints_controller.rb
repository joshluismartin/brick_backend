class Api::V1::BlueprintsController < ActionController::API
  # Skip all authentication and validation for now
  
  def index
    render json: {
      success: true,
      message: "Blueprints loaded successfully",
      data: {
        data: {
          blueprints: [
            {
              id: 1,
              title: "Sample Goal",
              description: "This is a test goal",
              status: "not_started",
              priority: "medium",
              category: "test",
              target_date: Date.current.to_s,
              progress_percentage: 0,
              milestones_count: 0,
              habits_count: 0,
              created_at: Time.current.to_s,
              updated_at: Time.current.to_s
            }
          ],
          total_count: 1
        }
      }
    }
  end

  def create
    render json: {
      success: true,
      message: "Blueprint created successfully",
      data: {
        data: {
          blueprint: {
            id: rand(1000),
            title: params.dig(:blueprint, :title) || "New Goal",
            description: params.dig(:blueprint, :description) || "New Description",
            status: "not_started",
            priority: "medium",
            category: params.dig(:blueprint, :category) || "general",
            target_date: Date.current.to_s,
            created_at: Time.current.to_s,
            updated_at: Time.current.to_s
          }
        }
      }
    }, status: :created
  end

  def show
    render json: {
      success: true,
      data: {
        data: {
          blueprint: {
            id: params[:id],
            title: "Test Goal",
            description: "Test Description"
          }
        }
      }
    }
  end

  def update
    render json: {
      success: true,
      message: "Blueprint updated successfully",
      data: {
        data: {
          blueprint: {
            id: params[:id],
            title: "Updated Goal"
          }
        }
      }
    }
  end

  def destroy
    render json: {
      success: true,
      message: "Blueprint deleted successfully",
      data: {
        data: {}
      }
    }
  end

  def complete
    render json: {
      success: true,
      message: "Blueprint completed successfully!",
      data: {
        data: {
          blueprint: {
            id: params[:id],
            status: "completed"
          }
        }
      }
    }
  end
end
