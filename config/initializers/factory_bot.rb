if Rails.env.test?
  FactoryBot.definition_file_paths = [Rails.root.join('test', 'factories')]
  FactoryBot.find_definitions
end
