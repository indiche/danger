require 'gitlab'
require 'uri'

module Danger
  module CISource
    class GitLabCI < CI
      def self.validates?(env)
        return !env["GITLAB_CI"].nil?
      end

      def initialize(env)
        repo_url = env["CI_BUILD_REPO"]
        project_id = env["CI_PROJECT_ID"]
        ref_name = env["CI_BUILD_REF_NAME"]

        self.repo_slug = parse_repo_url(repo_url)
        self.pull_request_id = fetch_merge_request_id(project_id, ref_name)
      end

      private
      def client
        endpoint = ENV["GITLAB_API_ENDPOINT"]
        token = ENV["GITLAB_API_PRIVATE_TOKEN"]

        raise "No API endpoint given, please provide one using `GITLAB_API_ENDPOINT`" unless endpoint
        raise "No API token given, please provide one using `GITLAB_API_PRIVATE_TOKEN`" unless token

        @client ||= Gitlab.client(endpoint: endpoint,
                                  private_token: token)
      end

      def parse_repo_url(url)
        paths = URI.parse(url).path.split('/')
        group = paths[1]
        project = File.basename(paths[2], File.extname(paths[2]))

        group + '/' + project
      end

      def fetch_merge_request_id(project_id, ref_name)
        merge_request = client.merge_requests(project_id).find do |mr|
          mr.source_branch == ref_name
        end

        if merge_request
          merge_request.id.to_s
        else
          ''
        end
      end
    end
  end
end
