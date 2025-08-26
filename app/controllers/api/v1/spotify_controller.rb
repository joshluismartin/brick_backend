class Api::V1::SpotifyController < Api::V1::BaseController
  # GET /api/v1/spotify/tracks/blueprint/:blueprint_id - Get tracks for a specific blueprint
  def blueprint_tracks
    blueprint = Blueprint.find(params[:blueprint_id])
    limit = params[:limit]&.to_i || 20

    tracks = SpotifyService.search_tracks_for_blueprint(blueprint, limit: limit)

    render_success({
      tracks: tracks,
      blueprint: {
        id: blueprint.id,
        title: blueprint.title,
        category: blueprint.category
      },
      count: tracks.length
    }, "Blueprint tracks retrieved successfully")
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  rescue => e
    Rails.logger.error "Spotify tracks error: #{e.message}"
    render_error("Failed to retrieve tracks from Spotify", :service_unavailable)
  end

  # GET /api/v1/spotify/playlists/:category - Get motivational playlists by category
  def category_playlists
    category = params[:category]
    limit = params[:limit]&.to_i || 10

    if category.blank?
      render_error("Category parameter is required", :bad_request)
      return
    end

    playlists = SpotifyService.get_motivational_playlists(category, limit: limit)

    render_success({
      playlists: playlists,
      category: category,
      count: playlists.length
    }, "Category playlists retrieved successfully")
  rescue => e
    Rails.logger.error "Spotify playlists error: #{e.message}"
    render_error("Failed to retrieve playlists from Spotify", :service_unavailable)
  end

  # POST /api/v1/spotify/playlist/blueprint/:blueprint_id - Create custom playlist for blueprint
  def create_blueprint_playlist
    blueprint = Blueprint.find(params[:blueprint_id])

    playlist = SpotifyService.create_blueprint_playlist(blueprint)

    render_success({
      playlist: playlist,
      blueprint: {
        id: blueprint.id,
        title: blueprint.title,
        category: blueprint.category
      }
    }, "Blueprint playlist created successfully")
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  rescue => e
    Rails.logger.error "Spotify playlist creation error: #{e.message}"
    render_error("Failed to create playlist", :service_unavailable)
  end

  # GET /api/v1/spotify/recommendations/blueprint/:blueprint_id - Get AI recommendations for blueprint
  def blueprint_recommendations
    blueprint = Blueprint.find(params[:blueprint_id])
    limit = params[:limit]&.to_i || 20

    recommendations = SpotifyService.get_recommendations_for_blueprint(blueprint, limit: limit)

    render_success({
      recommendations: recommendations,
      blueprint: {
        id: blueprint.id,
        title: blueprint.title,
        category: blueprint.category
      },
      count: recommendations.length,
      algorithm: "Spotify AI Recommendations"
    }, "Blueprint recommendations retrieved successfully")
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  rescue => e
    Rails.logger.error "Spotify recommendations error: #{e.message}"
    render_error("Failed to get recommendations from Spotify", :service_unavailable)
  end

  # GET /api/v1/spotify/audio_features - Get audio features and motivation scores for tracks
  def audio_features
    track_ids = params[:track_ids]

    if track_ids.blank?
      render_error("track_ids parameter is required", :bad_request)
      return
    end

    # Handle both comma-separated string and array
    ids_array = track_ids.is_a?(Array) ? track_ids : track_ids.split(",")

    features = SpotifyService.get_audio_features(ids_array)

    render_success({
      audio_features: features,
      track_count: features.length,
      analysis: "Audio features with motivation scoring"
    }, "Audio features retrieved successfully")
  rescue => e
    Rails.logger.error "Spotify audio features error: #{e.message}"
    render_error("Failed to get audio features from Spotify", :service_unavailable)
  end

  # GET /api/v1/spotify/search - General track search with filters
  def search
    query = params[:query]
    limit = params[:limit]&.to_i || 20

    if query.blank?
      render_error("Query parameter is required", :bad_request)
      return
    end

    begin
      SpotifyService.configure
      results = RSpotify::Track.search(query, limit: limit)
      formatted_tracks = SpotifyService.send(:format_tracks, results)

      render_success({
        tracks: formatted_tracks,
        query: query,
        count: formatted_tracks.length
      }, "Search results retrieved successfully")
    rescue => e
      Rails.logger.error "Spotify search error: #{e.message}"
      render_error("Failed to search Spotify", :service_unavailable)
    end
  end

  # GET /api/v1/spotify/habit_music/:habit_id - Get music for specific habit sessions
  def habit_music
    habit = Habit.find(params[:habit_id])
    milestone = habit.milestone
    blueprint = milestone.blueprint

    # Get tracks based on the blueprint but optimized for habit frequency
    tracks = SpotifyService.search_tracks_for_blueprint(blueprint, limit: 15)

    # Add habit-specific context
    habit_context = determine_habit_music_context(habit)

    render_success({
      tracks: tracks,
      habit: {
        id: habit.id,
        title: habit.title,
        frequency: habit.frequency
      },
      context: habit_context,
      suggested_duration: calculate_suggested_duration(habit),
      count: tracks.length
    }, "Habit-specific music retrieved successfully")
  rescue ActiveRecord::RecordNotFound
    render_error("Habit not found", :not_found)
  rescue => e
    Rails.logger.error "Habit music error: #{e.message}"
    render_error("Failed to retrieve habit music", :service_unavailable)
  end

  # GET /api/v1/spotify/daily_motivation - Get daily motivational music mix
  def daily_motivation
    # Get a mix of motivational tracks from different categories
    categories = [ "fitness", "business", "personal", "creative" ]
    all_tracks = []

    categories.each do |category|
      playlists = SpotifyService.get_motivational_playlists(category, limit: 2)
      # In a real implementation, we'd get tracks from these playlists
      # For now, we'll use search as a proxy
    end

    # Get general motivational tracks
    begin
      SpotifyService.configure
      motivational_tracks = RSpotify::Track.search("motivation success", limit: 20)
      formatted_tracks = SpotifyService.send(:format_tracks, motivational_tracks)

      render_success({
        tracks: formatted_tracks,
        mix_type: "Daily Motivation",
        categories_included: categories,
        count: formatted_tracks.length,
        refresh_time: Time.current + 24.hours
      }, "Daily motivational mix retrieved successfully")
    rescue => e
      Rails.logger.error "Daily motivation error: #{e.message}"
      render_error("Failed to create daily motivation mix", :service_unavailable)
    end
  end

  private

  def determine_habit_music_context(habit)
    frequency_context = {
      "daily" => "Short, energizing tracks for daily motivation",
      "weekly" => "Focused playlist for weekly goal sessions",
      "monthly" => "Extended mix for monthly milestone work"
    }

    {
      frequency_advice: frequency_context[habit.frequency] || "General motivational music",
      energy_level: habit.frequency == "daily" ? "high" : "medium",
      session_type: habit.frequency == "daily" ? "quick_boost" : "focused_work"
    }
  end

  def calculate_suggested_duration(habit)
    duration_mapping = {
      "daily" => "5-15 minutes",
      "weekly" => "30-60 minutes",
      "monthly" => "60-120 minutes"
    }

    duration_mapping[habit.frequency] || "15-30 minutes"
  end

  def spotify_params
    params.permit(:blueprint_id, :category, :limit, :query, :habit_id, track_ids: [])
  end
end
