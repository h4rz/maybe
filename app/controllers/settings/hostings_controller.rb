class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: :clear_cache

  def show
    alpha_vantage_provider = Provider::Registry.get_provider(:alpha_vantage)
    @alpha_vantage_usage = alpha_vantage_provider&.usage
    
    exchange_rate_api_provider = Provider::Registry.get_provider(:exchange_rate_api)
    @exchange_rate_api_usage = exchange_rate_api_provider&.usage
    
    logo_dev_provider = Provider::Registry.get_provider(:logo_dev)
    @logo_dev_usage = logo_dev_provider&.usage
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:alpha_vantage_api_key)
      Setting.alpha_vantage_api_key = hosting_params[:alpha_vantage_api_key]
    end

    if hosting_params.key?(:exchange_rate_api_key)
      Setting.exchange_rate_api_key = hosting_params[:exchange_rate_api_key]
    end

    if hosting_params.key?(:logo_dev_api_key)
      Setting.logo_dev_api_key = hosting_params[:logo_dev_api_key]
    end

    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  private
    def hosting_params
      params.require(:setting).permit(:require_invite_for_signup, :require_email_confirmation, :alpha_vantage_api_key, :exchange_rate_api_key, :logo_dev_api_key)
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
