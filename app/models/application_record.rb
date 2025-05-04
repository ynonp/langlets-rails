class ApplicationRecord < ActiveRecord::Base
  include HasTimestamp
  
  primary_abstract_class
end
