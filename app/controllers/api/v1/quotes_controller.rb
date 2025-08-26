class Api::V1::QuotesController < Api::V1::BaseController
  # GET /api/v1/quotes - Get random motivational quote
  def index
    quote = QuotableService.daily_motivation
    render_success(quote, "Daily motivational quote retrieved successfully")
  end

  # GET /api/v1/quotes/random - Get random quote with optional filters
  def random
    tags = params[:tags]
    min_length = params[:min_length]&.to_i
    max_length = params[:max_length]&.to_i

    quote = QuotableService.random_quote(
      tags: tags,
      min_length: min_length,
      max_length: max_length
    )

    render_success(quote, "Random quote retrieved successfully")
  end

  # GET /api/v1/quotes/blueprint/:blueprint_id - Get quote for specific blueprint
  def blueprint_quote
    blueprint = Blueprint.find(params[:blueprint_id])
    quote = QuotableService.quote_for_blueprint(blueprint)

    render_success({
      quote: quote,
      blueprint: {
        id: blueprint.id,
        title: blueprint.title,
        category: blueprint.category
      }
    }, "Blueprint-specific quote retrieved successfully")
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  # GET /api/v1/quotes/celebration - Get celebration quote for habit completion
  def celebration
    quote = QuotableService.completion_celebration_quote
    render_success(quote, "Celebration quote retrieved successfully")
  end

  # GET /api/v1/quotes/tags/:tags - Get multiple quotes by tags
  def by_tags
    tags = params[:tags]
    limit = params[:limit]&.to_i || 5

    if tags.blank?
      render_error("Tags parameter is required", :bad_request)
      return
    end

    quotes = QuotableService.quotes_by_tags(tags, limit: limit)
    render_success({
      quotes: quotes,
      count: quotes.length,
      tags: tags
    }, "Quotes by tags retrieved successfully")
  end

  # POST /api/v1/quotes/favorite - Save favorite quote (future feature)
  def create
    # This endpoint is prepared for when we add user authentication
    # Users will be able to save their favorite quotes

    quote_content = params[:content]
    quote_author = params[:author]

    if quote_content.blank?
      render_error("Quote content is required", :bad_request)
      return
    end

    # For now, just return the quote data
    # In the future, this will save to user's favorites
    favorite_quote = {
      content: quote_content,
      author: quote_author || "Unknown",
      saved_at: Time.current,
      id: SecureRandom.uuid
    }

    render_success(favorite_quote, "Quote saved to favorites (demo mode)")
  end

  # DELETE /api/v1/quotes/:id - Remove favorite quote (future feature)
  def destroy
    # This endpoint is prepared for when we add user authentication
    # Users will be able to remove quotes from their favorites

    quote_id = params[:id]

    render_success({
      id: quote_id,
      removed_at: Time.current
    }, "Quote removed from favorites (demo mode)")
  end

  private

  def quote_params
    params.permit(:content, :author, :tags, :min_length, :max_length, :limit, :blueprint_id)
  end
end
