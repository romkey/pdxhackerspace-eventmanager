class SiteConfigsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_site_config
  before_action :authorize_site_config

  def edit; end

  def update
    # Handle favicon removal
    @site_config.favicon.purge if params[:site_config][:remove_favicon] == '1'

    # Handle banner removal
    @site_config.banner_image.purge if params[:site_config][:remove_banner_image] == '1'

    # Remove the removal flags from params before updating
    params[:site_config].delete(:remove_favicon)
    params[:site_config].delete(:remove_banner_image)

    if @site_config.update(site_config_params)
      redirect_to edit_site_config_path, notice: 'Site configuration was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_site_config
    @site_config = SiteConfig.current
  end

  def authorize_site_config
    authorize @site_config
  end

  def site_config_params
    params.require(:site_config).permit(
      :organization_name,
      :website_url,
      :contact_email,
      :contact_phone,
      :footer_text,
      :favicon,
      :banner_image
    )
  end
end
