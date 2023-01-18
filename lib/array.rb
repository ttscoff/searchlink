# Array helpers
class ::Array
  def longest_element
    group_by(&:size).max.last[0]
  end
end
