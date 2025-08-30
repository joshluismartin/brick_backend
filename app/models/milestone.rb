class Milestone < ApplicationRecord
  belongs_to :blueprint
  belongs_to :user
  has_many :habits, dependent: :destroy

  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :target_date, presence: true
  validates :status, inclusion: { in: %w[pending in_progress completed] }
  validates :priority, inclusion: { in: %w[low medium high] }

  validate :target_date_cannot_be_in_past
  validate :target_date_before_blueprint_target

  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END")) }
  scope :by_target_date, -> { order(:target_date) }
  scope :active, -> { where(status: [ "pending", "in_progress" ]) }
  scope :completed, -> { where(status: "completed") }

  def progress_percentage
    return 0 if habits.count == 0
    completed_habits = habits.where(status: "completed").count
    (completed_habits.to_f / habits.count * 100).round(2)
  end

  def overdue?
    target_date < Date.current && status != "completed"
  end

  def days_remaining
    return 0 if target_date < Date.current
    (target_date - Date.current).to_i
  end

  private

  def target_date_cannot_be_in_past
    return unless target_date.present?

    if target_date < Date.current
      errors.add(:target_date, "can't be in the past")
    end
  end

  def target_date_before_blueprint_target
    return unless target_date.present? && blueprint&.target_date.present?

    if target_date > blueprint.target_date
      errors.add(:target_date, "can't be after blueprint target date")
    end
  end
end
