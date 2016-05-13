# coding: utf-8
require 'redcarpet'
require 'gitlab'

module Danger
  module PRSource
    class GitLab
      attr_accessor :ci_source, :project_id, :pr_json, :issue_json, :environment, :base_commit, :head_commit, :support_tokenless_auth, :ignored_violations, :github_host

      def self.validates?
        !env["GITLAB_CI"].nil?
      end

      def initialize(ci_source, environment)
        self.ci_source = ci_source
        self.environment = environment
      end

      def client
        raise "No API token given, please provide one using `GITLAB_API_PRIVATE_TOKEN`" if !ENV['GITLAB_API_PRIVATE_TOKEN']
        raise "No API endpoint given, please provide one using `GITLAB_API_ENDPOINT`" if !ENV['GITLAB_API_ENDPOINT']

        @client || = Gitlab.client(endpoint: ENV['GITLAB_API_ENDPOINT'],
                                  private_token: ENV['GITLAB_API_PRIVATE_TOKEN'])
      end

      def markdown_parser
        @markdown_parser ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: true)
      end

      def project_id
        @project_id ||= client.projects.auto_paginate.select do |p|
          p.path_with_namespace == ci_source.repo_slug
        end.map do |p|
          p.id
        end.first
      end

      def fetch_details
        self.pr_json = client.merge_request(self.project_id, ci_source.pull_request_id)
        fetch_issue_details(self.pr_json)
        self.ignored_violations = ignored_violations_from_pr(self.pr_json)
      end

      def ignored_violations_from_pr(pr_json)
        pr_body = pr_json[:body]
        return [] if pr_body.nil?
        pr_body.chomp.scan(/>\s*danger\s*:\s*ignore\s*"(.*)"/i).flatten
      end

      def fetch_issue_details(pr_json)
        href = pr_json[:_links][:issue][:href]
        self.issue_json = client.get(href)
      end

      def base_commit
        self.pr_json.target_branch
      end

      def head_commit
        self.pr_json.source_branch
      end

      def branch_for_merge
        raise "Don't know what this does"
      end

      def pr_title
        self.pr_json.title
      end

      def pr_body
        self.pr_json.description
      end

      def pr_author
        self.pr_json.author.username
      end

      def pr_labels
        self.pr_json.labels
      end

      # Sending data to GitHub
      def update_pull_request!(warnings: [], errors: [], messages: [], markdowns: [])
        comment_result = {}

        comments = client.merge_request_comments(project_id, ci_source.pull_request_id)
        editable_comments = comments.reject { |issue| issue[:body].include?("generated_by_danger") == false }

        if editable_comments.empty?
          previous_violations = {}
        else
          comment = editable_comments.first[:body]
          previous_violations = parse_comment(comment)
        end

        if previous_violations.empty? && (warnings + errors + messages + markdowns).empty?
          # Just remove the comment, if there's nothing to say.
          delete_old_comments!
        else
          body = generate_comment(warnings: warnings,
                                    errors: errors,
                                  messages: messages,
                                markdowns: markdowns,
                      previous_violations: previous_violations)

          if editable_issues.empty?
            comment_result = client.create_merge_request_note(project_id, ci_source.pull_request_id, body)
          else
            original_id = editable_issues.first.id
            comment_result = client.update_merge_request_note(project_id, original_id, body)
          end
        end

        # Now, set the pull request status.
        # Note: this can terminate the entire process.
        submit_pull_request_status!(warnings: warnings,
                                      errors: errors)
      end

      def submit_pull_request_status!(warnings: nil, errors: nil, details_url: nil)
        status = (errors.count == 0 ? 'success' : 'failure')
        message = generate_github_description(warnings: warnings, errors: errors)
        # client.create_status(ci_source.repo_slug, latest_pr_commit_ref, status, {
        #   description: message,
        #   context: "danger/danger",
        #   target_url: details_url
        # })
      rescue
        # This usually means the user has no commit access to this repo
        # That's always the case for open source projects where you can only
        # use a read-only GitHub account
        if errors.count > 0
          # We need to fail the actual build here
          abort("\nDanger has failed this build. \nFound #{'error'.danger_pluralize(errors.count)} and I don't have write access to the PR set a PR status.")
        else
          puts message
        end
      end

      # Get rid of the previously posted comment, to only have the latest one
      def delete_old_comments!(except: nil)
        # issues = client.issue_comments(ci_source.repo_slug, ci_source.pull_request_id)
        # issues.each do |issue|
        #   next unless issue[:body].include?("generated_by_danger")
        #   next if issue[:id] == except
        #   client.delete_comment(ci_source.repo_slug, issue[:id])
        # end
      end

      def random_compliment
        compliment = ["Well done.", "Congrats.", "Woo!",
                      "Yay.", "Jolly good show.", "Good on 'ya.", "Nice work."]
        compliment.sample
      end

      def generate_github_description(warnings: nil, errors: nil)
        if errors.empty? && warnings.empty?
          return "All green. #{random_compliment}"
        else
          message = "⚠ "
          message += "#{'Error'.danger_pluralize(errors.count)}. " unless errors.empty?
          message += "#{'Warning'.danger_pluralize(warnings.count)}. " unless warnings.empty?
          message += "Don't worry, everything is fixable."
          return message
        end
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

      def violations_from_table(table)
        regex = %r{<td data-sticky="true">(?:<del>)?(.*?)(?:</del>)?\s*</td>}im
        table.scan(regex).flatten.map(&:strip)
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

      def parse_tables_from_comment(comment)
        comment.split('</table>')
      end

      def process_markdown(violation)
        html = markdown_parser.render(violation.message)
        match = html.match(%r{^<p>(.*)</p>$})
        message = match.nil? ? html : match.captures.first
        Violation.new(message, violation.sticky)
      end
    end
  end
end
