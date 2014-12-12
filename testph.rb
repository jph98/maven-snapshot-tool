#!/usr/bin/env ruby

gem "minitest"

require "minitest/autorun"
require 'minitest/pride'

require_relative "ph"

class TestPh < Minitest::Test

	def setup

		@ph = Ph.new()      
    end  

    def test_pom

    end
end