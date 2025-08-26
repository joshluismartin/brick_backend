class Api::V1::MilestonesController < Api::V1::BaseController
  before_action :set_blueprint
  before_action :set_milestone, only: [ :show, :update, :destroy ]

  # GET /api/v1/blueprints/:blueprint_id/milestones
  def index
    @milestones = @blueprint.milestones.by_target_date
    render_success(@milestones.as_json(include: :habits, methods: [ :progress_percentage, :overdue?, :days_remaining ]))
  end

  # GET /api/v1/blueprints/:blueprint_id/milestones/:id
  def show
    render_success(@milestone.as_json(
      include: :habits,
      methods: [ :progress_percentage, :overdue?, :days_remaining ]
    ))
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones
  def create
    @milestone = @blueprint.milestones.build(milestone_params)

    if @milestone.save
      render_success(
        @milestone.as_json(methods: [ :progress_percentage, :overdue?, :days_remaining ]),
        "Milestone created successfully"
      )
    else
      render_error(@milestone.errors.full_messages.join(", "))
    end
  end

  # PATCH/PUT /api/v1/blueprints/:blueprint_id/milestones/:id
  def update
    if @milestone.update(milestone_params)
      render_success(
        @milestone.as_json(methods: [ :progress_percentage, :overdue?, :days_remaining ]),
        "Milestone updated successfully"
      )
    else
      render_error(@milestone.errors.full_messages.join(", "))
    end
  end

  # DELETE /api/v1/blueprints/:blueprint_id/milestones/:id
  def destroy
    @milestone.destroy
    render_success(nil, "Milestone deleted successfully")
  end

  private

  def set_blueprint
    @blueprint = Blueprint.find(params[:blueprint_id])
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  def set_milestone
    @milestone = @blueprint.milestones.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Milestone not found", :not_found)
  end

  def milestone_params
    params.require(:milestone).permit(:title, :description, :target_date, :status, :priority)
  end
end
