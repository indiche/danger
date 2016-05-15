require 'danger/ci_source/gitlab_ci'

describe Danger::CISource::GitLabCI do
  it 'validates when GitLab ENV variable is found' do
    env = { "GITLAB_CI" => "true" }
    expect(Danger::CISource::GitLabCI.validates?(env)).to be true
  end

  it 'doesnt validate when GitLab ENV variable isnt found' do
    env = { "NOT_GITLAB_CI" => "true" }
    expect(Danger::CISource::GitLabCI.validates?(env)).to be false
  end

  describe '.initialize' do
    before :each do
      allow(ENV).to receive(:[]).with('GITLAB_API_ENDPOINT').and_return('http://test.url.com')
      allow(ENV).to receive(:[]).with('GITLAB_API_PRIVATE_TOKEN').and_return('secret')

      @env = {
          "CI_BUILD_REF_NAME" => "test1",
          "CI_BUILD_REPO" => "https://gitlab.com/gitlab-org/gitlab-ce.git",
          "CI_PROJECT_ID" => "34"
      }
    end

    context 'there is merge request' do
      it 'figures out repo slug and merge request number' do
        stub_request(:get, 'http://test.url.com/projects/34/merge_requests').
            with(headers: { 'Private-Token' => 'secret' }).
            to_return(body: fixture('gitlab_merge_requests_response'))

        subject = Danger::CISource::GitLabCI.new(@env)

        expect(subject.repo_slug).to eql('gitlab-org/gitlab-ce')
        expect(subject.pull_request_id).to eql('1')
      end
    end

    context 'there isnt merge request' do
      it 'leaves merge request number as empty string' do
        stub_request(:get, 'http://test.url.com/projects/34/merge_requests').
            with(headers: { 'Private-Token' => 'secret' }).
            to_return(body: '[]')

        subject = Danger::CISource::GitLabCI.new(@env)

        expect(subject.repo_slug).to eql('gitlab-org/gitlab-ce')
        expect(subject.pull_request_id).to eql('')
      end
    end
  end
end
