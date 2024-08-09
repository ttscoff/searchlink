# Array helpers
class ::Array
  # 
  # This method takes an array and returns the longest element of that array.
  #
  # @return [String] Longest string in array
  #
  def longest_element
    group_by(&:size).max.last[0]
  end
end
