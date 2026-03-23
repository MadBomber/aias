# frozen_string_literal: true

module Aias
  # Converts a cron expression or @ keyword into a plain-English description.
  # Returns the original expression unchanged for anything it cannot parse,
  # so it is always safe to call.
  #
  # Usage:
  #   CronDescriber.describe("0 8 * * *")         # => "every day at 8:00am"
  #   CronDescriber.describe("0 8 * * 1-5")       # => "every weekday at 8:00am"
  #   CronDescriber.display("0 8 * * *")           # => "every day at 8:00am (0 8 * * *)"
  class CronDescriber
    DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

    MONTHS = [
      nil, "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ].freeze

    KEYWORDS = {
      "@yearly"   => "every year",
      "@annually" => "every year",
      "@monthly"  => "every month",
      "@weekly"   => "every Sunday at midnight",
      "@daily"    => "every day at midnight",
      "@midnight" => "every day at midnight",
      "@hourly"   => "every hour"
    }.freeze

    # Returns "plain english (expr)".
    def self.display(expr)
      desc = describe(expr)
      desc == expr ? expr : "#{desc} (#{expr})"
    end

    # Returns only the plain-English description (or the original expr on failure).
    def self.describe(expr)
      new(expr.to_s.strip).describe
    end

    def initialize(expr)
      @expr = expr
    end

    def describe
      return KEYWORDS[@expr] if KEYWORDS.key?(@expr)

      parts = @expr.split
      return @expr unless parts.size == 5

      min, hour, dom, mon, dow = parts

      # Fall back for step expressions (*/n) — we don't describe these.
      return @expr if [min, hour, dom, mon, dow].any? { |f| f.include?("/") }

      "#{describe_date(dom, mon, dow)}#{describe_time(min, hour)}"
    rescue StandardError
      @expr
    end

    private

    # -------------------------------------------------------------------------
    # Time
    # -------------------------------------------------------------------------

    def describe_time(min, hour)
      return "" if hour == "*" && min == "*"
      return " at every minute" if hour != "*" && min == "*"
      return "" if hour == "*"

      format_clock(hour.to_i, min.to_i)
    end

    def format_clock(hour, min)
      ampm = hour < 12 ? "am" : "pm"
      h    = hour % 12
      h    = 12 if h == 0
      m    = min.zero? ? "" : ":#{min.to_s.rjust(2, '0')}"
      " at #{h}#{m}#{ampm}"
    end

    # -------------------------------------------------------------------------
    # Date
    # -------------------------------------------------------------------------

    def describe_date(dom, mon, dow)
      if dom == "*" && dow == "*"
        mon == "*" ? "every day" : "every #{month_name(mon)}"
      elsif dom != "*" && dow == "*"
        suffix = mon == "*" ? "monthly" : "every #{month_name(mon)}"
        "#{suffix} on the #{ordinal(dom.to_i)}"
      else
        # dow is specified (dom may also be set — cron ORs them, but dow wins here)
        "every #{describe_dow(dow)}"
      end
    end

    def describe_dow(dow)
      case dow
      when /^\d+$/
        DAYS[dow.to_i % 7]
      when /^(\d+)-(\d+)$/
        a = Regexp.last_match(1).to_i % 7
        b = Regexp.last_match(2).to_i % 7
        return "weekday"   if a == 1 && b == 5
        return "day"       if (a == 0 && b == 6) || (a == 0 && b == 7 % 7)

        "#{DAYS[a]}\u2013#{DAYS[b]}"
      when /^\d+(,\d+)+$/
        days = dow.split(",").map { |d| d.to_i % 7 }
        # Fugit normalises "1-5" (weekday range) to "1,2,3,4,5" — detect that.
        return "weekday" if days == [1, 2, 3, 4, 5]

        days.map { |d| DAYS[d] }.join(", ")
      else
        dow
      end
    end

    def month_name(mon)
      return mon unless mon.match?(/^\d+$/)

      MONTHS[mon.to_i] || mon
    end

    def ordinal(n)
      suffix =
        case n % 100
        when 11, 12, 13 then "th"
        else
          case n % 10
          when 1 then "st"
          when 2 then "nd"
          when 3 then "rd"
          else "th"
          end
        end
      "#{n}#{suffix}"
    end
  end
end
