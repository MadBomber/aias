# frozen_string_literal: true

require "test_helper"

class TestCronDescriber < Minitest::Test
  # ---------------------------------------------------------------------------
  # @ keywords
  # ---------------------------------------------------------------------------

  def test_daily_keyword
    assert_equal "every day at midnight", describe("@daily")
  end

  def test_midnight_keyword
    assert_equal "every day at midnight", describe("@midnight")
  end

  def test_hourly_keyword
    assert_equal "every hour", describe("@hourly")
  end

  def test_monthly_keyword
    assert_equal "every month", describe("@monthly")
  end

  def test_weekly_keyword
    assert_equal "every Sunday at midnight", describe("@weekly")
  end

  def test_yearly_keyword
    assert_equal "every year", describe("@yearly")
  end

  def test_annually_keyword
    assert_equal "every year", describe("@annually")
  end

  # ---------------------------------------------------------------------------
  # Time formatting
  # ---------------------------------------------------------------------------

  def test_top_of_hour_am
    assert_equal "every day at 8am", describe("0 8 * * *")
  end

  def test_top_of_hour_pm
    assert_equal "every day at 3pm", describe("0 15 * * *")
  end

  def test_midnight
    assert_equal "every day at 12am", describe("0 0 * * *")
  end

  def test_noon
    assert_equal "every day at 12pm", describe("0 12 * * *")
  end

  def test_half_past
    assert_equal "every Monday at 7:30am", describe("30 7 * * 1")
  end

  def test_minutes_preserved
    assert_equal "every day at 9:15am", describe("15 9 * * *")
  end

  # ---------------------------------------------------------------------------
  # Day-of-week
  # ---------------------------------------------------------------------------

  def test_weekday_range
    assert_equal "every weekday at 8am", describe("0 8 * * 1-5")
  end

  def test_single_weekday_monday
    assert_equal "every Monday at 9am", describe("0 9 * * 1")
  end

  def test_single_weekday_friday
    assert_equal "every Friday at 9am", describe("0 9 * * 5")
  end

  def test_sunday_as_zero
    assert_equal "every Sunday at 8am", describe("0 8 * * 0")
  end

  def test_sunday_as_seven
    assert_equal "every Sunday at 8am", describe("0 8 * * 7")
  end

  # ---------------------------------------------------------------------------
  # Day-of-month
  # ---------------------------------------------------------------------------

  def test_first_of_month
    assert_equal "monthly on the 1st at 8am", describe("0 8 1 * *")
  end

  def test_second_of_month
    assert_equal "monthly on the 2nd at 8am", describe("0 8 2 * *")
  end

  def test_third_of_month
    assert_equal "monthly on the 3rd at 8am", describe("0 8 3 * *")
  end

  def test_eleventh_of_month
    assert_equal "monthly on the 11th at 8am", describe("0 8 11 * *")
  end

  # ---------------------------------------------------------------------------
  # display — appends (expr) to the description
  # ---------------------------------------------------------------------------

  def test_display_appends_expr_in_parens
    result = Aias::CronDescriber.display("0 8 * * *")
    assert_equal "every day at 8am (0 8 * * *)", result
  end

  def test_display_keyword
    result = Aias::CronDescriber.display("@daily")
    assert_equal "every day at midnight (@daily)", result
  end

  # ---------------------------------------------------------------------------
  # Fallback for unknown/complex expressions
  # ---------------------------------------------------------------------------

  def test_unknown_expression_returns_unchanged
    expr = "*/15 * * * *"
    assert_equal expr, describe(expr)
  end

  def test_display_unknown_returns_expr_only
    expr = "*/15 * * * *"
    assert_equal expr, Aias::CronDescriber.display(expr)
  end

  private

  def describe(expr)
    Aias::CronDescriber.describe(expr)
  end
end
