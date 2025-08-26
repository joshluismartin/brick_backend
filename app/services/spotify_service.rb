require "rspotify"

class SpotifyService
  # Configure RSpotify with credentials
  def self.configure
    RSpotify.authenticate(
      ENV["SPOTIFY_CLIENT_ID"] || Rails.application.credentials.spotify&.client_id,
      ENV["SPOTIFY_CLIENT_SECRET"] || Rails.application.credentials.spotify&.client_secret
    )
  end

  # Search for tracks based on Blueprint category and mood
  def self.search_tracks_for_blueprint(blueprint, limit: 20)
    configure

    # Generate search terms based on blueprint
    search_terms = generate_search_terms(blueprint)
    tracks = []

    search_terms.each do |term|
      begin
        results = RSpotify::Track.search(term, limit: limit / search_terms.length)
        tracks.concat(results)
      rescue => e
        Rails.logger.error "Spotify search error for term '#{term}': #{e.message}"
      end
    end

    # Remove duplicates and format response
    unique_tracks = tracks.uniq { |track| track.id }
    format_tracks(unique_tracks.first(limit))
  end

  # Get motivational playlists for different goal categories
  def self.get_motivational_playlists(category, limit: 10)
    configure

    playlist_queries = {
      "fitness" => [ "workout motivation", "gym music", "running playlist" ],
      "business" => [ "focus music", "productivity playlist", "work motivation" ],
      "education" => [ "study music", "concentration playlist", "focus beats" ],
      "creative" => [ "creative flow", "inspiration music", "artistic vibes" ],
      "personal" => [ "motivation", "self improvement", "positive vibes" ]
    }

    queries = playlist_queries[category.downcase] || playlist_queries["personal"]
    playlists = []

    queries.each do |query|
      begin
        results = RSpotify::Playlist.search(query, limit: limit / queries.length)
        playlists.concat(results)
      rescue => e
        Rails.logger.error "Spotify playlist search error for '#{query}': #{e.message}"
      end
    end

    format_playlists(playlists.first(limit))
  end

  # Create a custom playlist for a Blueprint (requires user authentication)
  def self.create_blueprint_playlist(blueprint, user_spotify_id = nil)
    configure

    # For now, return a mock playlist since we don't have user auth
    # In the future, this will create actual Spotify playlists
    {
      id: "mock_playlist_#{blueprint.id}",
      name: "#{blueprint.title} - Goal Achievement Playlist",
      description: "Curated music to help you achieve: #{blueprint.title}",
      tracks_count: 25,
      duration_ms: 1500000, # ~25 minutes
      external_url: "https://open.spotify.com/playlist/mock_playlist_#{blueprint.id}",
      created_at: Time.current,
      blueprint_id: blueprint.id,
      suggested_tracks: search_tracks_for_blueprint(blueprint, limit: 25)
    }
  end

  # Get audio features for motivation analysis
  def self.get_audio_features(track_ids)
    configure

    begin
      features = RSpotify::AudioFeatures.find(track_ids)
      features.map do |feature|
        {
          track_id: feature.id,
          energy: feature.energy,
          valence: feature.valence,
          danceability: feature.danceability,
          tempo: feature.tempo,
          motivation_score: calculate_motivation_score(feature)
        }
      end
    rescue => e
      Rails.logger.error "Spotify audio features error: #{e.message}"
      []
    end
  end

  # Get recommendations based on Blueprint goals
  def self.get_recommendations_for_blueprint(blueprint, limit: 20)
    configure

    # Use seed tracks and audio features for recommendations
    seed_genres = determine_genres_for_blueprint(blueprint)
    target_features = determine_target_features(blueprint)

    begin
      recommendations = RSpotify::Recommendations.generate(
        seed_genres: seed_genres,
        limit: limit,
        target_energy: target_features[:energy],
        target_valence: target_features[:valence],
        target_danceability: target_features[:danceability]
      )

      format_tracks(recommendations.tracks)
    rescue => e
      Rails.logger.error "Spotify recommendations error: #{e.message}"
      # Fallback to search if recommendations fail
      search_tracks_for_blueprint(blueprint, limit: limit)
    end
  end

  private

  def self.generate_search_terms(blueprint)
    title_words = blueprint.title.downcase.split(/\W+/)
    category = blueprint.category&.downcase || "motivation"

    # Base motivational terms
    base_terms = [ "motivation", "success", "achievement", "focus" ]

    # Category-specific terms
    category_terms = {
      "fitness" => [ "workout", "gym", "running", "training" ],
      "business" => [ "productivity", "focus", "work", "success" ],
      "education" => [ "study", "concentration", "learning", "focus" ],
      "creative" => [ "inspiration", "creativity", "flow", "artistic" ],
      "personal" => [ "self improvement", "growth", "positive", "uplifting" ]
    }

    terms = base_terms + (category_terms[category] || category_terms["personal"])

    # Add blueprint-specific keywords
    blueprint_keywords = title_words.select { |word| word.length > 3 }
    terms.concat(blueprint_keywords.first(2))

    terms.uniq.first(5)
  end

  def self.determine_genres_for_blueprint(blueprint)
    category = blueprint.category&.downcase || "personal"

    genre_mapping = {
      "fitness" => [ "electronic", "pop", "hip-hop" ],
      "business" => [ "ambient", "classical", "electronic" ],
      "education" => [ "ambient", "classical", "chill" ],
      "creative" => [ "indie", "alternative", "electronic" ],
      "personal" => [ "pop", "indie", "alternative" ]
    }

    genre_mapping[category] || genre_mapping["personal"]
  end

  def self.determine_target_features(blueprint)
    category = blueprint.category&.downcase || "personal"

    feature_mapping = {
      "fitness" => { energy: 0.8, valence: 0.7, danceability: 0.7 },
      "business" => { energy: 0.6, valence: 0.6, danceability: 0.4 },
      "education" => { energy: 0.4, valence: 0.5, danceability: 0.3 },
      "creative" => { energy: 0.6, valence: 0.6, danceability: 0.5 },
      "personal" => { energy: 0.7, valence: 0.7, danceability: 0.6 }
    }

    feature_mapping[category] || feature_mapping["personal"]
  end

  def self.calculate_motivation_score(audio_feature)
    # Calculate motivation score based on energy, valence, and tempo
    energy_weight = 0.4
    valence_weight = 0.4
    tempo_weight = 0.2

    # Normalize tempo (typical range 60-200 BPM)
    normalized_tempo = [ (audio_feature.tempo - 60) / 140.0, 1.0 ].min

    score = (audio_feature.energy * energy_weight) +
            (audio_feature.valence * valence_weight) +
            (normalized_tempo * tempo_weight)

    (score * 100).round(2)
  end

  def self.format_tracks(tracks)
    tracks.map do |track|
      {
        id: track.id,
        name: track.name,
        artist: track.artists.first&.name,
        album: track.album&.name,
        duration_ms: track.duration_ms,
        preview_url: track.preview_url,
        external_url: track.external_urls["spotify"],
        popularity: track.popularity,
        explicit: track.explicit
      }
    end
  end

  def self.format_playlists(playlists)
    playlists.map do |playlist|
      {
        id: playlist.id,
        name: playlist.name,
        description: playlist.description,
        tracks_count: playlist.total,
        external_url: playlist.external_urls["spotify"],
        owner: playlist.owner&.display_name,
        public: playlist.public,
        collaborative: playlist.collaborative
      }
    end
  end
end
