module Danger
  module PRSource
    class PR
      attr_accessor :pr_head_location, :pr_target_branch

      def self.validates?(_env)
        false
      end

      def initialize(_ci_source, _env)
        raise 'Subclass and overwrite'
      end

      def fetch_details
        raise 'Subclass and overwrite'
      end

      def update_pull_request!(_warnings: [], _errors: [], _messages: [], _markdowns: [])
        raise 'Subclass and overwrite'
      end
    end
  end
end
