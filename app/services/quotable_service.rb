require "net/http"
require "json"

class QuotableService
  BASE_URL = "https://api.quotable.io"

  # Get a random motivational quote
  def self.random_quote(tags: nil, min_length: nil, max_length: nil)
    params = {}
    params[:tags] = tags if tags
    params[:minLength] = min_length if min_length
    params[:maxLength] = max_length if max_length

    url = build_url("/random", params)
    response = make_request(url)

    if response
      {
        content: response["content"],
        author: response["author"],
        tags: response["tags"],
        length: response["length"]
      }
    else
      fallback_quote
    end
  end

  def self.quote_for_blueprint(blueprint)
    tags = determine_tags_for_blueprint(blueprint)
    random_quote(tags: tags, min_length: 50, max_length: 200)
  end

  def self.daily_motivation
    motivational_tags = "motivational,inspirational,success,wisdom"
    random_quote(tags: motivational_tags, min_length: 40, max_length: 150)
  end

  def self.quotes_by_tags(tags, limit: 5)
    params = { tags: tags, limit: limit }
    url = build_url("/quotes", params)
    response = make_request(url)

    if response && response["results"]
      response["results"].map do |quote|
        {
          content: quote["content"],
          author: quote["author"],
          tags: quote["tags"],
          length: quote["length"]
        }
      end
    else
      [ fallback_quote ]
    end
  end

  def self.completion_celebration_quote
    celebration_tags = "success,motivational,inspirational"
    quote = random_quote(tags: celebration_tags, max_length: 100)

    if quote[:content]
      quote[:content] = "🎉 #{quote[:content]}"
    end

    quote
  end

  private

  def self.build_url(endpoint, params = {})
    uri = URI("#{BASE_URL}#{endpoint}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    uri
  end

  def self.make_request(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Get.new(url)
    request["Accept"] = "application/json"

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "Quotable API Error: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Quotable API Request Error: #{e.message}"
    nil
  end

  def self.determine_tags_for_blueprint(blueprint)
    title_words = blueprint.title.downcase.split(/\W+/)

    tag_mapping = {
      %w[fitness workout gym exercise health] => "motivational,health,success",
      %w[business work career money financial] => "business,success,motivational",
      %w[study learn education skill knowledge] => "wisdom,education,success",
      %w[creative art music write design] => "inspirational,wisdom,creativity",
      %w[relationship family love social] => "friendship,love,wisdom",
      %w[travel adventure explore experience] => "inspirational,motivational,life"
    }

    matching_tags = tag_mapping.find do |keywords, _|
      (title_words & keywords).any?
    end

    matching_tags ? matching_tags[1] : "motivational,inspirational,success"
  end

  def self.fallback_quote
    {
      content: "The journey of a thousand miles begins with one step.",
      author: "Lao Tzu",
      tags: [ "motivational", "wisdom" ],
      length: 54
    }
  end
end
