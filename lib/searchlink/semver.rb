module SL
  class SemVer < String
    attr_accessor :maj, :min, :patch, :pre

    def initialize(semver)
      @maj, @min, @patch = semver.split(/\./)
      if @patch =~ /([^0-9]+\d?)$/
        @pre = Regexp.last_match(1)
        @patch = @patch.sub(/([^0-9]+)$/, '')
      else
        @pre = nil
      end

      @maj = @maj.to_i
      @min = @min.to_i
      @patch = @patch.to_i
    end

    def older_than(semver)
      latest = semver.is_a?(SemVer) ? semver : SemVer.new(semver)

      return false if latest.equal?(self)

      if latest.maj > @maj
        true
      elsif latest.min > @min
        true
      else
        latest.patch > @patch
      end
    end

    def newer_than(semver)
      v = semver.is_a?(SemVer) ? semver : SemVer.new(semver)
      v.older_than(self) && !v.equal?(self)
    end

    def equal?(other)
      v = other.is_a?(SemVer) ? other : SemVer.new(other)

      v.maj == @maj && v.min == @min && v.patch == @patch && v.pre == @pre
    end

    def inspect
      {
        'maj' => @maj,
        'min' => @min,
        'patch' => @patch,
        'pre' => @pre
      }
    end

    def to_s
      "#{@maj}.#{@min}.#{@patch}#{@pre}"
    end
  end
end
