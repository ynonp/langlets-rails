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
    regex = Regexp.new(/['\p{L}][\p{L}\p{M}]*(?:'[\p{L}\p{M}]+)*/u)

    Enumerator.new do |y|
      pos = 0
      while m = regex.match(self, pos)
        y << m
        pos = m.end(0)
      end
    end
  end
end

