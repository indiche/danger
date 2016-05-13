# coding: utf-8

module Danger
  module PRSource
  class PR
   def self.validates?(_env)
      false
    end

    def initialize(_ci_source, _env)
      raise "Subclass and overwrite initialize"
    end
  end
end
