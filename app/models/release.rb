# frozen_string_literal: true

class Release < ApplicationRecord
  include CacheMarkdownField
  include Gitlab::Utils::StrongMemoize

  cache_markdown_field :description

  belongs_to :project
  # releases prior to 11.7 have no author
  belongs_to :author, class_name: 'User'

  has_many :links, class_name: 'Releases::Link'

  has_many :milestone_releases
  has_many :milestones, through: :milestone_releases

  default_value_for :released_at, allows_nil: false do
    Time.zone.now
  end

  accepts_nested_attributes_for :links, allow_destroy: true

  validates :description, :project, :tag, presence: true
  validates_associated :milestone_releases, message: -> (_, obj) { obj[:value].map(&:errors).map(&:full_messages).join(",") }

  scope :sorted, -> { order(released_at: :desc) }

  delegate :repository, to: :project

  def commit
    strong_memoize(:commit) do
      repository.commit(actual_sha)
    end
  end

  def tag_missing?
    actual_tag.nil?
  end

  def assets_count(except: [])
    links_count = links.count
    sources_count = except.include?(:sources) ? 0 : sources.count

    links_count + sources_count
  end

  def sources
    strong_memoize(:sources) do
      Releases::Source.all(project, tag)
    end
  end

  def upcoming_release?
    released_at.present? && released_at > Time.zone.now
  end

  private

  def actual_sha
    sha || actual_tag&.dereferenced_target
  end

  def actual_tag
    strong_memoize(:actual_tag) do
      repository.find_tag(tag)
    end
  end
end

Release.prepend_if_ee('EE::Release')
