class String
  def nth_index(substring, n)
    return nil if n < 0
    index = -1
    (n + 1).times do
      index = self.index(substring, index + 1)
      return nil if index.nil?
    end
    index
  end

  def tokenize
    self.scan(/\p{L}+(?:'\p{L}+)*/u)
  end
end

