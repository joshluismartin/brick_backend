class Api::V1::BlueprintsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_blueprint, only: [:show, :update, :destroy, :complete]

  def index
    blueprints = current_user.blueprints.includes(:milestones, :user)
    
    render_success("Blueprints loaded successfully", {
      blueprints: blueprints.map do |blueprint|
        {
          id: blueprint.id,
          title: blueprint.title,
          description: blueprint.description,
          status: blueprint.status,
          priority: blueprint.priority,
          category: blueprint.category,
          target_date: blueprint.target_date,
          progress_percentage: blueprint.progress_percentage,
          milestones_count: blueprint.milestones.count,
          created_at: blueprint.created_at,
          updated_at: blueprint.updated_at
        }
      end,
      total_count: blueprints.count
    })
  end

  def show
    render_success("Blueprint loaded successfully", {
      blueprint: blueprint_json(@blueprint)
    })
  end

  def create
    blueprint = current_user.blueprints.build(blueprint_params)
    
    if blueprint.save
      render_success("Blueprint created successfully", {
        blueprint: blueprint_json(blueprint)
      }, :created)
    else
      render_error("Failed to create blueprint: #{blueprint.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  def update
    if @blueprint.update(blueprint_params)
      render_success("Blueprint updated successfully", {
        blueprint: blueprint_json(@blueprint)
      })
    else
      render_error("Failed to update blueprint: #{@blueprint.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  def destroy
    @blueprint.destroy
    render_success("Blueprint deleted successfully")
  end

  def complete
    @blueprint.update(status: 'completed', completed_at: Time.current)
    render_success("Blueprint marked as completed", {
      blueprint: blueprint_json(@blueprint)
    })
  end

  private

  def set_blueprint
    @blueprint = current_user.blueprints.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  def blueprint_params
    params.require(:blueprint).permit(:title, :description, :priority, :category, :target_date, :status)
  end

  def blueprint_json(blueprint)
    {
      id: blueprint.id,
      title: blueprint.title,
      description: blueprint.description,
      status: blueprint.status,
      priority: blueprint.priority,
      category: blueprint.category,
      target_date: blueprint.target_date,
      progress_percentage: blueprint.progress_percentage,
      milestones_count: blueprint.milestones.count,
      created_at: blueprint.created_at,
      updated_at: blueprint.updated_at
    }
  end
end
