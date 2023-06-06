# frozen_string_literal: true

require 'json'

module Test
  module Fixture
    FIXTURE_PATH = File.expand_path(__dir__)

    def load_fixture(file_name)
      File.read(File.join(FIXTURE_PATH, file_name))
    end

    def load_json_fixture(file_name)
      JSON.parse(load_fixture(file_name))
    end
  end
end
