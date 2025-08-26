# Spotify API Configuration
require "rspotify"

Rails.application.configure do
  # Spotify API settings
  config.spotify = ActiveSupport::OrderedOptions.new

  # Application name for Spotify API
  config.spotify.application_name = "BRICK Goal Achievement App"

  # Client credentials for Spotify Web API
  config.spotify.client_id = ENV["SPOTIFY_CLIENT_ID"]
  config.spotify.client_secret = ENV["SPOTIFY_CLIENT_SECRET"]

  # Redirect URI for OAuth (when we implement user authentication)
  config.spotify.redirect_uri = ENV["SPOTIFY_REDIRECT_URI"] || "http://localhost:3000/auth/spotify/callback"

  # Scopes for user authentication (future feature)
  config.spotify.scopes = [
    "playlist-modify-public",
    "playlist-modify-private",
    "playlist-read-private",
    "user-read-private",
    "user-read-email"
  ]
end

# Initialize RSpotify with basic authentication
# This allows us to search tracks and get recommendations without user auth
if Rails.application.config.spotify.client_id.present? && Rails.application.config.spotify.client_secret.present?
  RSpotify.authenticate(
    Rails.application.config.spotify.client_id,
    Rails.application.config.spotify.client_secret
  )

  Rails.logger.info "Spotify API initialized successfully"
else
  Rails.logger.warn "Spotify API credentials not found. Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET environment variables."
end

# Configure RSpotify for Rails (when we add user authentication)
# RSpotify::authenticate(client_id, client_secret)
#
# For user-specific features like creating playlists, we'll need:
# 1. User OAuth flow
# 2. Access tokens stored per user
# 3. Token refresh mechanism
