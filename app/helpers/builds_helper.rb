module BuildsHelper
  def build_ref_link build
    gitlab_ref_link build.project, build.ref
  end

  def build_commit_link build
    gitlab_commit_link build.project, build.short_sha
  end

  def build_url(build)
    ci_project_build_url(build.project, build)
  end
end
