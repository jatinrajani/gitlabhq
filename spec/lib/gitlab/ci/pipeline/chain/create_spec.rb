require 'spec_helper'

describe Gitlab::Ci::Pipeline::Chain::Create do
  set(:project) { create(:project) }
  set(:user) { create(:user) }

  let(:pipeline) do
    build(:ci_empty_pipeline, project: project, ref: 'master')
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, current_user: user)
  end

  let(:step) { described_class.new(pipeline, command) }

  context 'when pipeline is ready to be saved' do
    before do
      pipeline.stages.build(name: 'test', position: 0, project: project)

      step.perform!
    end

    it 'saves a pipeline' do
      expect(pipeline).to be_persisted
    end

    it 'does not break the chain' do
      expect(step.break?).to be false
    end

    it 'creates stages' do
      expect(pipeline.reload.stages).to be_one
      expect(pipeline.stages.first).to be_persisted
    end
  end

  context 'when pipeline has validation errors' do
    let(:pipeline) do
      build(:ci_pipeline, project: project, ref: nil)
    end

    before do
      step.perform!
    end

    it 'breaks the chain' do
      expect(step.break?).to be true
    end

    it 'appends validation error' do
      expect(pipeline.errors.to_a)
        .to include /Failed to persist the pipeline/
    end
  end

  context 'when build is related to environment' do
    before do
      pipeline.stages.build(name: 'test', position: 0, project: project)
      pipeline.builds << build(:ci_build, environment: 'production')
    end

    it 'creates an environment' do
      expect do
        step.perform!
      end.to change { Environment.count }.from(0).to(1)
    end

    it 'creates a build-environment-deployment relationship' do
      expect do
        step.perform!
      end.to change { Ci::BuildEnvironmentDeployment.count }.from(0).to(1)
    end
  end
end
