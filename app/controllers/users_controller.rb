class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: %i[show edit update destroy make_admin]
  before_action :authorize_user, only: %i[index show edit update destroy make_admin]

  def index
    authorize User
    @users = User.order(created_at: :desc)
  end

  def show; end

  def edit; end

  def update
    if @user.update(user_params)
      redirect_to @user, notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_url, notice: 'User was successfully deleted.'
  end

  def make_admin
    authorize @user, :make_admin?
    @user.update(role: 'admin')
    redirect_to @user, notice: 'User is now an admin.'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user
    authorize @user || User
  end

  def user_params
    permitted = params.require(:user).permit(:name, :email)
    # Only admins can change roles, and only to valid values
    permitted[:role] = params[:user][:role] if current_user.admin? && params[:user][:role].present? && %w[user admin].include?(params[:user][:role])
    permitted
  end
end
