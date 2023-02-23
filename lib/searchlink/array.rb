# Array helpers
class ::Array
  # Finds the longest element in a given array.
  def longest_element
    group_by(&:size).max.last[0]
  end
end
