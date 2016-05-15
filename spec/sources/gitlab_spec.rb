require 'danger/request_sources/gitlab'

describe Danger::PRSource::GitLab do
  before :each do
    allow(ENV).to receive(:[]).with('GITLAB_API_ENDPOINT').and_return('http://test.url.com')
    allow(ENV).to receive(:[]).with('GITLAB_API_PRIVATE_TOKEN').and_return('secret')
    stub_request(:get, 'http://test.url.com/projects').
        with(headers: { 'Private-Token' => 'secret' }).
        to_return(body: fixture('gitlab_projects_response'))

    stub_request(:get, 'http://test.url.com/projects/6/merge_request/1').
        with(headers: { 'Private-Token' => 'secret' }).
        to_return(body: fixture('gitlab_merge_request_response'))

    ci_source = double("ci_source", { repo_slug: 'brightbox/puppet', pull_request_id: '1' })
    @subject = Danger::PRSource::GitLab.new(ci_source, nil)
  end

  it 'validates if "DANGER_REQUEST_SOURCE" ENV variable is GitLab' do
    env = { "DANGER_REQUEST_SOURCE" => "GitLab" }
    expect(Danger::PRSource::GitLab.validates?(env)).to be true
  end

  it 'doesnt validate if "DANGER_REQUEST_SOURCE" ENV variable is not GitLab' do
    env = { "DANGER_REQUEST_SOURCE" => "NotAGitLab" }
    expect(Danger::PRSource::GitLab.validates?(env)).to be false
  end

  describe '.fetch_details' do
    it 'fetches merge request details' do
      @subject.fetch_details

      expect(@subject.merge_request).to be_truthy
    end
  end

  describe '.pr_target_branch' do
    it 'returns target branch of the merge request' do
      @subject.fetch_details

      expect(@subject.pr_target_branch).to eql('master')
    end
  end

  describe '.pr_head_location' do
    it 'returns location of the HEAD of the merge request' do
      @subject.fetch_details

      expect(@subject.pr_head_location).to eql('+refs/merge-requests/1/head')
    end
  end

  describe '.update_pull_request!' do
    it 'creates a new pull request comment' do
      @subject.update_pull_request!(warnings: [], errors: [], messages: [], markdowns: [])
    end
  end
end
