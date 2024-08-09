# Array helpers
class ::Array
  # 
  # This method takes an array and returns the longest element of that array.
  #
  # @return [String] Longest string in array
  #
  def longest_element
    longest_elements[0]
  end
  # Finds the longest elements and returns an Array
  #
  # @return [Array] array of longest elements
  def longest_elements
    group_by(&:size).max.last
  end

  # Finds the shortest element in an array of strings
  #
  # @return [String] first element among shortest elements
  def shortest_element
    shortest_elements[0]
  end

  # Finds the shortest elements in an array of strings
  #
  # @return [Array] array of shortest elements
  def shortest_elements
    group_by(&:size).min.last
  end
end
