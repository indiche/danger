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

  context 'there is merge request' do
    it 'figures out repo slug and merge request number' do
      response = fixture("gitlab_merge_requests_response")
      stub_request(:get, "http://test.url.com/projects/34/merge_requests").
        with(:headers => {'Accept'=>'application/json', 'Private-Token'=>'secret'}).
        to_return(:status => 200, :body => response, :headers => {})

      allow(ENV).to receive(:[]).with("GITLAB_API_ENDPOINT").and_return("http://test.url.com")
      allow(ENV).to receive(:[]).with("GITLAB_API_PRIVATE_TOKEN").and_return("secret")

      env = {
        "CI_BUILD_REF_NAME" => "test1",
        "CI_BUILD_REPO" => "https://gitlab.com/gitlab-org/gitlab-ce.git",
        "CI_PROJECT_ID" => "34"
      }

      subject = Danger::CISource::GitlabCI.new(env)

      expect(subject.repo_slug).to eql("gitlab-org/gitlab-ce")
      expect(subject.pull_request_id).to eql("1")
    end
  end

  context 'there isnt merge request' do
    it 'leaves merge request number as empty string' do
      stub_request(:get, "http://test.url.com/projects/34/merge_requests").
        with(:headers => {'Accept'=>'application/json', 'Private-Token'=>'secret'}).
        to_return(:status => 200, :body => '[]', :headers => {})

      allow(ENV).to receive(:[]).with("GITLAB_API_ENDPOINT").and_return("http://test.url.com")
      allow(ENV).to receive(:[]).with("GITLAB_API_PRIVATE_TOKEN").and_return("secret")

      env = {
        "CI_BUILD_REF_NAME" => "test1",
        "CI_BUILD_REPO" => "https://gitlab.com/gitlab-org/gitlab-ce.git",
        "CI_PROJECT_ID" => "34"
      }

      subject = Danger::CISource::GitlabCI.new(env)

      expect(subject.repo_slug).to eql("gitlab-org/gitlab-ce")
      expect(subject.pull_request_id).to eql("")
    end
  end
end
