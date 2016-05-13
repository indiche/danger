# coding: utf-8

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

      def fetch_details
      end
    end
  end
end
