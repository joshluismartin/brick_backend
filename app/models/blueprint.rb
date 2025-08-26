class Blueprint < ApplicationRecord
  belongs_to :user, optional: true  # optional for now since we don't have users yet
  has_many :milestones, dependent: :destroy
  has_many :habits, through: :milestones

  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10 }
  validates :status, inclusion: { in: %w[active completed paused] }
  validates :target_date, presence: true

  validate :target_date_cannot_be_in_past

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :by_target_date, -> { order(:target_date) }

  after_initialize :set_defaults

  def playlist_keywords
    title.downcase.split(/\W+/).reject { |word| word.length < 3 }
  end

  def suggested_playlist_genre
    case title.downcase
    when /workout|fitness|gym|exercise/
      "workout"
    when /study|learn|education|exam/
      "focus"
    when /work|career|business|productivity/
      "motivation"
    when /creative|art|writing|design/
      "chill"
    else
      "motivation"
    end
  end

  # Calculate overall progress based on milestones
  def progress_percentage
    return 0 if milestones.count == 0
    completed_milestones = milestones.where(status: 'completed').count
    (completed_milestones.to_f / milestones.count * 100).round(2)
  end

  # Check if blueprint is overdue
  def overdue?
    target_date < Date.current && status != 'completed'
  end

  # Days remaining until target date
  def days_remaining
    return 0 if target_date < Date.current
    (target_date - Date.current).to_i
  end

  private

  def target_date_cannot_be_in_past
    if target_date.present? && target_date < Date.current
      errors.add(:target_date, "can't be in the past")
    end
  end

  def set_defaults
    self.status ||= "active"
  end
end
