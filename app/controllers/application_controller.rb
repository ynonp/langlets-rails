class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  protected

  # Redirect to returnto param after successful sign in
  def after_sign_in_path_for(resource)
    if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end

  # Redirect to returnto param after successful sign up
  def after_sign_up_path_for(resource)
    if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end

  # Redirect to returnto param after successful sign out
  def after_sign_out_path_for(resource_or_scope)
    if params[:returnto].present?
      params[:returnto]
    else
      root_path
    end
  end
end
