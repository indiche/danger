require 'gitlab'
require 'uri'

module Danger
  module CISource
    class GitlabCI < CI
      def self.validates?(env)
        return !env["GITLAB_CI"].nil?
      end

      def initialize(env)
        Gitlab.endpoint = env["GITLAB_API_ENDPOINT"]
        Gitlab.private_token = env["GITLAB_API_PRIVATE_TOKEN"]

        repo_url = env["CI_BUILD_REPO"]
        project_id = env["CI_PROJECT_ID"]
        ref_name = env["CI_BUILD_REF_NAME"]

        self.repo_slug = parse_repo_url(repo_url)
        self.pull_request_id = fetch_merge_request_id(project_id, ref_name)
      end

      private
      def parse_repo_url(url)
        paths = URI.parse(url).path.split("/")
        group = paths[1]
        project = File.basename(paths[2], '.git')

        group + '/' + project
      end

      def fetch_merge_request_id(project_id, ref_name)
        Gitlab.merge_requests(project_id).select do |merge_request|
          merge_request.source_branch == ref_name
        end.map do |merge_request|
          merge_request.id
        end.first.to_s
      end

    end
  end
end
