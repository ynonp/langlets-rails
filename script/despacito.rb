l = Lesson.find_by(slug: "despacito")
l.activities = []

a = Activities::WatchVideoActivity.new(order: 1)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::MatchPhrasesActivity.new(order: 2)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::SortPhrasesActivity.new(order: 3)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::LanguageAlignmentActivity.new(order: 4)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::FindAnswerActivity.new(order: 5)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::SpeakActivity.new(order: 6)
a.phrases = Phrase.first(4)
l.activities << a

a = Activities::WatchVideoActivity.new(order: 1)
a.phrases = Phrase.first(4)
l.activities << a
