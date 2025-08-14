class AddSampleTagsAndAssignments < ActiveRecord::Migration[8.0]
  def up
    # Create sample tags
    music_tag = Tag.find_or_create_by!(name: 'Music')
    french_tag = Tag.find_or_create_by!(name: 'French')
    hip_hop_tag = Tag.find_or_create_by!(name: 'French hip hop music')
    beginner_tag = Tag.find_or_create_by!(name: 'Beginner')
    intermediate_tag = Tag.find_or_create_by!(name: 'Intermediate')
    
    # Assign tags to existing courses (if any)
    Course.published.each_with_index do |course, index|
      # Assign some sample tags to demonstrate functionality
      case index % 4
      when 0
        course.tags << [music_tag, french_tag] unless course.tags.include?(music_tag)
      when 1
        course.tags << [beginner_tag] unless course.tags.include?(beginner_tag)
      when 2
        course.tags << [hip_hop_tag, music_tag] unless course.tags.include?(hip_hop_tag)
      when 3
        course.tags << [intermediate_tag, french_tag] unless course.tags.include?(intermediate_tag)
      end
    end
  end

  def down
    # Remove all course tag assignments
    CourseTag.delete_all
    
    # Optionally remove the tags (be careful in production)
    Tag.where(name: ['Music', 'French', 'French hip hop music', 'Beginner', 'Intermediate']).delete_all
  end
end
