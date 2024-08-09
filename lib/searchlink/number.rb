# frozen_string_literal: true

class ::Float
  def to_datetime
    DateTime.parse(Time.at(self).to_s).next_year(31)
  end
end

class ::Integer
  def to_datetime
    DateTime.parse(Time.at(self).to_s).next_year(31)
  end
end
