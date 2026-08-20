# The platform's one curated, globally listed Channel.
#
# Unlike a user's personal Channel, publication here is an editorial action by
# Langlets rather than a purchase by the administrator account that owns the
# row. Its STI type owns that distinction: Channel#publish! remains the single
# publication path, while this subclass makes that path free.
class SystemChannel < Channel
  validates :default, :share, exclusion: { in: [ true ] }

  def self.instance
    first || create_or_find_by!(slug: SYSTEM_SLUG) do |channel|
      channel.user = User.find_by!(email: User::ADMIN_EMAIL)
      channel.name = SYSTEM_NAME
    end
  end

  # System visibility is an STI behavior, not persisted state. The inherited
  # column may contain any ordinary visibility without changing how this class
  # presents itself or participates in authorization.
  def visibility
    "system"
  end

  def visibility_system?
    true
  end

  def visibility_private?
    false
  end

  def visibility_shared?
    false
  end

  def visibility_public?
    false
  end

  def change_visibility!(_new_visibility, actor: nil)
    raise UnauthorizedTransition, "the system Channel's visibility is fixed"
  end

  private

  def charge_for!(_course)
    nil
  end
end
