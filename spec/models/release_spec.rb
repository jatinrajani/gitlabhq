# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Release do
  let(:user)    { create(:user) }
  let(:project) { create(:project, :public, :repository) }
  let(:release) { create(:release, project: project, author: user) }

  it { expect(release).to be_valid }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to have_many(:links).class_name('Releases::Link') }
    it { is_expected.to have_many(:milestones) }
    it { is_expected.to have_many(:milestone_releases) }
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:description) }

    context 'when a release exists in the database without a name' do
      it 'does not require name' do
        existing_release_without_name = build(:release, project: project, author: user, name: nil)
        existing_release_without_name.save(validate: false)

        existing_release_without_name.description = "change"
        existing_release_without_name.save
        existing_release_without_name.reload

        expect(existing_release_without_name).to be_valid
        expect(existing_release_without_name.description).to eq("change")
        expect(existing_release_without_name.name).to be_nil
      end
    end

    context 'when a release is tied to a milestone for another project' do
      it 'creates a validation error' do
        milestone = build(:milestone, project: create(:project))
        expect { release.milestones << milestone }.to raise_error
      end
    end

    context 'when a release is tied to a milestone linked to the same project' do
      it 'successfully links this release to this milestone' do
        milestone = build(:milestone, project: project)
        expect { release.milestones << milestone }.to change { MilestoneRelease.count }.by(1)
      end
    end
  end

  describe '#assets_count' do
    subject { release.assets_count }

    it 'returns the number of sources' do
      is_expected.to eq(Releases::Source::FORMATS.count)
    end

    context 'when a links exists' do
      let!(:link) { create(:release_link, release: release) }

      it 'counts the link as an asset' do
        is_expected.to eq(1 + Releases::Source::FORMATS.count)
      end

      it "excludes sources count when asked" do
        assets_count = release.assets_count(except: [:sources])
        expect(assets_count).to eq(1)
      end
    end
  end

  describe '#sources' do
    subject { release.sources }

    it 'returns sources' do
      is_expected.to all(be_a(Releases::Source))
    end
  end

  describe '#upcoming_release?' do
    context 'during the backfill migration when released_at could be nil' do
      it 'handles a nil released_at value and returns false' do
        allow(release).to receive(:released_at).and_return nil

        expect(release.upcoming_release?).to eq(false)
      end
    end
  end
end
