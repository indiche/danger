module Danger
  module PRSource
    class PR
      attr_accessor :ci_source, :pr_json, :issue_json, :environment, :base_commit, :head_commit

      def self.validates?(_env)
        false
      end

      def initialize(_ci_source, _env)
        raise "Subclass and overwrite initialize"
      end

      def client
      end

      def fetch_details
      end

      def fetch_issue_details(_pr_json)
      end

      def base_commit
      end

      def head_commit
      end

      def pr_title
      end

      def pr_body
      end

      def pr_author
      end

      def pr_labels
      end

      def update_pull_request!(warnings: nil, errors: nil, messages: nil)
      end
    end
  end
end
