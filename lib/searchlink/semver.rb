module SL
  # Semantic versioning library
  class SemVer
    attr_accessor :maj, :min, :patch, :pre

    # Initialize a Semantic Version object
    #
    # @param      version_string  [String] a semantic version number
    #
    # @return     [SemVer] SemVer object
    #
    def initialize(version_string)
      raise "Invalid semantic version number: #{version_string}" unless version_string.valid_version?

      @maj, @min, @patch = version_string.split(/\./)
      @pre = nil
      if @patch =~ /(-?[^0-9]+\d*)$/
        @pre = Regexp.last_match(1).sub(/^-/, '')
        @patch = @patch.sub(/(-?[^0-9]+)$/, '')
      end

      @maj = @maj.to_i
      @min = @min.to_i
      @patch = @patch.to_i
    end

    ##
    ## SemVer String helpers
    ##
    class ::String
      # Test if given string is a valid semantic version
      # number with major, minor and patch (and optionally
      # pre)
      #
      # @return     [Boolean] string is semantic version number
      #
      def valid_version?
        pattern = /^\d+\.\d+\.\d+(-?([^0-9]+\d*))?$/
        self =~ pattern ? true : false
      end
    end

    ##
    ## Test if self is older than a semantic version number
    ##
    ## @param      semver  [String,SemVer] The semantic version number or SemVer object
    ##
    ## @return     [Boolean] true if semver is older
    ##
    def older_than(other)
      latest = other.is_a?(SemVer) ? other : SemVer.new(other)

      return false if latest.equal?(self)

      if @maj > latest.maj
        false
      elsif @maj < latest.maj
        true
      elsif @min > latest.min
        false
      elsif @min < latest.min
        true
      elsif @patch > latest.patch
        false
      elsif @patch < latest.patch
        true
      else
        return false if @pre.nil? && latest.pre.nil?

        return true if @pre.nil? && !latest.pre.nil?

        return false if !@pre.nil? && latest.pre.nil?

        @pre < latest.pre
      end
    end

    ##
    ## @see        #older_than
    ##
    def <(other)
      older_than(other)
    end

    ##
    ## Test if self is newer than a semantic version number
    ##
    ## @param      semver  [String,SemVer] The semantic version number or SemVer object
    ##
    ## @return     [Boolean] true if semver is newer
    ##
    def newer_than(other)
      v = other.is_a?(SemVer) ? other : SemVer.new(other)
      v.older_than(self) && !v.equal?(self)
    end

    ##
    ## @see        #newer_than
    ##
    def >(other)
      newer_than(other)
    end

    ##
    ## Test if self is equal to other
    ##
    ## @param      other [String,SemVer] The other semantic version number
    ##
    ## @return     [Boolean] values are equal
    ##
    def equal?(other)
      v = other.is_a?(SemVer) ? other : SemVer.new(other)

      v.maj == @maj && v.min == @min && v.patch == @patch && v.pre == @pre
    end

    ##
    ## @see #equal?
    ##
    def ==(other)
      equal?(other)
    end

    def inspect
      {
        object_id: object_id,
        maj: @maj,
        min: @min,
        patch: @patch,
        pre: @pre
      }
    end

    def to_s
      [[@maj, @min, @patch].join('.'), @pre].join('-')
    end
  end
end
