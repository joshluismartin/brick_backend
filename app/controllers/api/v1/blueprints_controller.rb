class Api::V1::BlueprintsController < Api::V1::BaseController
  before_action :set_blueprint, only: [ :show, :update, :destroy ]

  # GET /api/v1/blueprints
  def index
    @blueprints = Blueprint.all.by_target_date
    render_success(@blueprints.as_json(include: :milestones))
  end

  # GET /api/v1/blueprints/:id
  def show
    render_success(@blueprint.as_json(
      include: :milestones,
      methods: [ :playlist_keywords, :suggested_playlist_genre ]
    ))
  end

  # POST /api/v1/blueprints
  def create
    @blueprint = Blueprint.new(blueprint_params)

    if @blueprint.save
      render_success(@blueprint.as_json(
        methods: [ :playlist_keywords, :suggested_playlist_genre ]
      ), "Blueprint created successfully")
    else
      render_error(@blueprint.errors.full_messages.join(", "))
    end
  end

  # PUT/PATCH /api/v1/blueprints/:id
  def update
    if @blueprint.update(blueprint_params)
      render_success(@blueprint.as_json(
        methods: [ :playlist_keywords, :suggested_playlist_genre ]
      ), "Blueprint updated successfully")
    else
      render_error(@blueprint.errors.full_messages.join(", "))
    end
  end

  # DELETE /api/v1/blueprints/:id
  def destroy
    @blueprint.destroy
    render_success(nil, "Blueprint deleted successfully")
  end

  private

  def set_blueprint
    @blueprint = Blueprint.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  def blueprint_params
    params.require(:blueprint).permit(:title, :description, :target_date, :status)
  end
end
