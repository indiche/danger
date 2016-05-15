require 'danger/environment_manager'

describe Danger::EnvironmentManager do
  it 'raises without enough info in the ENV' do
    expect do
      Danger::EnvironmentManager.new({ "KEY" => "VALUE" })
    end.to raise_error("Could not find a CI source".red)
  end

  it 'stores travis in the source' do
    number = 123
    env = { "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true", "TRAVIS_REPO_SLUG" => "KrauseFx/fastlane", "TRAVIS_PULL_REQUEST" => number.to_s }
    e = Danger::EnvironmentManager.new(env)
    expect(e.ci_source.pull_request_id).to eq(number.to_s)
  end

  it 'stores circle in the source' do
    number = 800
    env = { "CIRCLE_BUILD_NUM" => "true", "CI_PULL_REQUEST" => "https://github.com/artsy/eigen/pull/#{number}" }
    e = Danger::EnvironmentManager.new(env)
    expect(e.ci_source.pull_request_id).to eq(number.to_s)
  end

  it 'stores gitlab in the source' do
    stub_request(:get, 'http://test.url.com/projects/34/merge_requests').
        with(headers: { 'Private-Token' => 'secret' }).
        to_return(body: fixture('gitlab_merge_requests_response'))

    allow(ENV).to receive(:[]).with('GITLAB_API_ENDPOINT').and_return('http://test.url.com')
    allow(ENV).to receive(:[]).with('GITLAB_API_PRIVATE_TOKEN').and_return('secret')

    env = {
        "GITLAB_CI" => "true",
        "CI_BUILD_REF_NAME" => "test1",
        "CI_BUILD_REPO" => "https://gitlab.com/gitlab-org/gitlab-ce.git",
        "CI_PROJECT_ID" => "34"
    }

    e = Danger::EnvironmentManager.new(env)
    expect(e.ci_source.pull_request_id).to eq('1')
  end

  it 'sets gitlab as request source' do
    env = {
        "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
        "TRAVIS_REPO_SLUG" => "KrauseFx/fastlane",
        "TRAVIS_PULL_REQUEST" => 123.to_s,
        "DANGER_REQUEST_SOURCE" => "GitLab"
    }

    e = Danger::EnvironmentManager.new(env)
    expect(e.request_source).to be_an_instance_of(Danger::PRSource::GitLab)
  end

  it 'creates a GitHub attr' do
    env = { "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true", "TRAVIS_REPO_SLUG" => "KrauseFx/fastlane", "TRAVIS_PULL_REQUEST" => 123.to_s }
    e = Danger::EnvironmentManager.new(env)
    expect(e.request_source).to be_truthy
  end

  it 'skips push runs and only runs for pull requests' do
    env = { "TRAVIS_REPO_SLUG" => "orta/danger", "TRAVIS_PULL_REQUEST" => "false", "HAS_JOSH_K_SEAL_OF_APPROVAL" => "1" }
    e = Danger::EnvironmentManager.new(env)
    expect(e.ci_source).to eq(nil)
  end
end
