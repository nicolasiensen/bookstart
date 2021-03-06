# coding: utf-8
class UsersController < ApplicationController
  after_filter :verify_authorized, except: %i[reactivate]
  inherit_resources
  defaults finder: :find_active!
  actions :show, :update, :unsubscribe_notifications, :credits, :destroy, :edit
  respond_to :json, only: [:contributions, :projects]

  def destroy
    authorize resource
    resource.deactivate
    sign_out(current_user) if current_user == resource
    flash[:notice] = t('users.current_user_fields.deactivate_notice', name: resource.name)
    redirect_to root_path
  end

  def unsubscribe_notifications
    authorize resource
    redirect_to user_path(current_user, anchor: 'unsubscribes')
  end

  def credits
    authorize resource
    redirect_to user_path(current_user, anchor: 'credits')
  end

  def settings
    authorize resource
    redirect_to user_path(current_user, anchor: 'settings')
  end

  def show
    authorize resource
    show!{
      fb_admins_add(@user.facebook_id) if @user.facebook_id
      @title = "#{@user.display_name}"
      @credits = @user.contributions.can_refund
      @subscribed_to_posts = @user.posts_subscription
      @unsubscribes = @user.project_unsubscribes
      @credit_cards = @user.credit_cards
      build_bank_account
    }
  end

  def reactivate
    user = params[:token].present? && User.find_by(reactivate_token: params[:token])
    if user
      user.reactivate
      sign_in user
      flash[:notice] = t('users.reactivated')
    else
      flash[:error] = t('users.failed_reactivation')
    end
    redirect_to root_path
  end

  def edit
    authorize resource
    @unsubscribes = @user.project_unsubscribes
    @subscribed_to_posts = @user.posts_subscription
    resource.links.build
  end

  def update
    authorize resource

    if update_user
      flash[:notice] = t('users.current_user_fields.updated')
      redirect_to edit_user_path(@user, anchor: params[:anchor])
    else
      flash.now[:notice] = @user.errors.full_messages.to_sentence
      render :edit
    end
  end

  private

  def update_user
    drop_and_create_subscriptions
    update_reminders
    update_category_followers

    if password_params_given?
      @user.update_with_password permitted_params[:user]
    else
      @user.update_attributes permitted_params[:user]
    end
  end

  def category_followers_params_given?
    permitted_params[:user][:category_followers_attributes].present?
  end

  def password_params_given?
    permitted_params[:user][:current_password].present? || permitted_params[:user][:password].present?
  end

  def update_category_followers
    resource.category_followers.clear if category_followers_params_given?
  end

  def update_reminders
    @user.projects_in_reminder.each do |project|
      unless params[:user][:reminders] && params[:user][:reminders].find {|p| p['project_id'] == project.id.to_s}
        project.delete_from_reminder_queue(@user.id)
      end
    end
  end

  def drop_and_create_subscriptions
    #unsubscribe to all projects
    if params[:subscribed].nil?
      @user.unsubscribes.create!(project_id: nil)
    else
      @user.unsubscribes.drop_all_for_project(nil)
    end
    if params[:unsubscribes]
      params[:unsubscribes].each do |subscription|
        project_id = subscription[0].to_i
        #change from unsubscribed to subscribed
        if subscription[1].present?
          @user.unsubscribes.drop_all_for_project(project_id)
        #change from subscribed to unsubscribed
        else
          @user.unsubscribes.create!(project_id: project_id)
        end
      end
    end
  end

  def resource
    @user ||= params[:id].present? ? User.find_active!(params[:id]) : User.with_permalink.find_by_permalink(request.subdomain)
  end

  def build_bank_account
    @user.build_bank_account unless @user.bank_account
  end

  def permitted_params
    params.permit(policy(resource).permitted_attributes)
  end

  def use_catarse_boostrap
    ["show", "edit", "update"].include?(action_name) ? 'catarse_bootstrap' : 'application'
  end
end
