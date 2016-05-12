require 'danger/ci_source/gitlab_ci'

describe Danger::CISource::GitlabCI do
  it 'validates when gitlab env var is found' do
    env = { "GITLAB_CI" => "true" }
    expect(Danger::CISource::GitlabCI.validates?(env)).to be true
  end

  it 'doesnt validate when gitlab env var isnt found' do
    env = { "NOT_GITLAB_CI" => "true" }
    expect(Danger::CISource::GitlabCI.validates?(env)).to be false
  end

  it 'figures out repo slug and merge request number' do
    response = fixture("gitlab_merge_requests_response")
    stub_request(:get, "http://test.url.com/projects/34/merge_requests").
      with(:headers => {'Accept'=>'application/json', 'Private-Token'=>'secret'}).
      to_return(:status => 200, :body => response, :headers => {})

    env = {
      "CI_BUILD_REF_NAME" => "test1",
      "CI_BUILD_REPO" => "https://gitlab.com/gitlab-org/gitlab-ce.git",
      "CI_PROJECT_ID" => "34",
      "GITLAB_API_ENDPOINT" => "http://test.url.com",
      "GITLAB_API_PRIVATE_TOKEN" => "secret"
    }

    subject = Danger::CISource::GitlabCI.new(env)

    expect(subject.repo_slug).to eql("gitlab-org/gitlab-ce")
    expect(subject.pull_request_id).to eql("1")
  end
end
