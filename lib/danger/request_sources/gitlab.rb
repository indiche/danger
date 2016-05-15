# coding: utf-8
require 'danger/request_sources/pr_source'
require 'redcarpet'
require 'gitlab'

module Danger
  module PRSource
    class GitLab < PR
      attr_accessor :merge_request

      def self.validates?(env)
        return env["DANGER_REQUEST_SOURCE"] == 'GitLab'
      end

      def initialize(ci_source, _env)
        @ci_source = ci_source
      end

      def pr_target_branch
        self.merge_request.target_branch
      end

      def pr_head_location
        "+refs/merge-requests/#{@ci_source.pull_request_id}/head"
      end

      def fetch_details
        self.merge_request = client.merge_request(project.id, @ci_source.pull_request_id)
      end

      def update_pull_request!(warnings: [], errors: [], messages: [], markdowns: [])
        comments = previous_notes

        if comments.empty?
          previous_violations = {}
        else
          comment = comments.first
          previous_violations = parse_comment(comment.body)
        end

        if previous_violations.empty? and (warnings + errors + messages + markdowns).empty?
          comments.each do |note|
            client.delete_merge_request_note(project.id, merge_request.id, note.id)
          end
        else
          body = generate_comment(warnings: warnings,
                                  errors: errors,
                                  messages: messages,
                                  markdowns: markdowns,
                                  previous_violations: previous_violations)

          if comments.empty?
            client.create_merge_request_note(project.id, merge_request.id, body)
          else
            note = comments.first
            client.modify_merge_request_note(project.id, merge_request.id, note.id, body)
          end
        end
      end

      private

      def project
        @project = client.projects.auto_paginate.find do |project|
          project.path_with_namespace == @ci_source.repo_slug
        end
      end

      def previous_notes
        client.merge_request_notes(project.id, merge_request.id).reject do |note|
          !note.body.include?('generated_by_danger')
        end
      end

      def parse_comment(comment)
        tables = parse_tables_from_comment(comment)
        violations = {}
        tables.each do |table|
          next unless table =~ %r{<th width="100%"(.*?)</th>}im
          title = Regexp.last_match(1)
          kind = table_kind_from_title(title)
          next unless kind

          violations[kind] = violations_from_table(table)
        end

        violations.reject { |_, v| v.empty? }
      end

      def parse_tables_from_comment(comment)
        comment.split('</table>')
      end

      def violations_from_table(table)
        regex = %r{<td data-sticky="true">(?:<del>)?(.*?)(?:</del>)?\s*</td>}im
        table.scan(regex).flatten.map(&:strip)
      end

      def generate_comment(warnings: [], errors: [], messages: [], markdowns: [], previous_violations: {})
        require 'erb'

        md_template = File.join(Danger.gem_path, "lib/danger/comment_generators/github.md.erb")

        # erb: http://www.rrn.dk/rubys-erb-templating-system
        # for the extra args: http://stackoverflow.com/questions/4632879/erb-template-removing-the-trailing-line
        @tables = [
            table("Error", "no_entry_sign", errors, previous_violations),
            table("Warning", "warning", warnings, previous_violations),
            table("Message", "book", messages, previous_violations)
        ]
        @markdowns = markdowns

        return ERB.new(File.read(md_template), 0, "-").result(binding)
      end

      def table(name, emoji, violations, all_previous_violations)
        content = violations.map { |v| process_markdown(v) }
        kind = table_kind_from_title(name)
        previous_violations = all_previous_violations[kind] || []
        messages = content.map(&:message)
        resolved_violations = previous_violations.reject { |s| messages.include? s }
        count = content.count
        { name: name, emoji: emoji, content: content, resolved: resolved_violations, count: count }
      end

      def process_markdown(violation)
        html = markdown_parser.render(violation.message)
        match = html.match(%r{^<project>(.*)</project>$})
        message = match.nil? ? html : match.captures.first
        Violation.new(message, violation.sticky)
      end

      def table_kind_from_title(title)
        if title =~ /error/i
          :error
        elsif title =~ /warning/i
          :warning
        elsif title =~ /message/i
          :message
        end
      end

      def markdown_parser
        @markdown_parser ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: true)
      end

      def client
        endpoint = ENV["GITLAB_API_ENDPOINT"]
        token = ENV["GITLAB_API_PRIVATE_TOKEN"]

        raise "No API endpoint given, please provide one using `GITLAB_API_ENDPOINT`" unless endpoint
        raise "No API token given, please provide one using `GITLAB_API_PRIVATE_TOKEN`" unless token

        @client ||= Gitlab.client(endpoint: endpoint,
                                  private_token: token)
      end
    end
  end
end
