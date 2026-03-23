# frozen_string_literal: true

require "test_helper"

class TestAias < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Aias::VERSION
  end

  def test_version_is_a_string
    assert_kind_of String, ::Aias::VERSION
  end

  def test_error_is_standard_error_subclass
    assert Aias::Error < StandardError
  end

  def test_all_expected_classes_defined
    assert_kind_of Class, Aias::CLI
    assert_kind_of Class, Aias::PromptScanner
    assert_kind_of Class, Aias::Validator
    assert_kind_of Class, Aias::JobBuilder
    assert_kind_of Class, Aias::CrontabManager
  end
end
