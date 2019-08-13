module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, except: %i[index]

    def index
      @pagy, @users = pagy(User.filter_by(permitted_params[:filter_by]))
    end

    def delete
      @user.soft_delete_with_relations
      redirect_to admin_users_path(filter_by: :deleted)
    end

    def restore
      @user.restore
      @user.restore_relations
    end

    def unspam
      @user.ham!
      @user.update_attribute :is_spam, false
      @user.restore
      @user.restore_relations
    end

    def spam
      @user.spam_and_mark_for_deletion!
      respond_to do |format|
        format.html { redirect_to admin_users_path(filter_by: :is_spam) }
        format.js
      end
    end

    def mark_all_users_with_ip_as_spam
      ip = @user.current_login_ip
      count = User.where(current_login_ip: ip).count
      MarkAllUsersWithIpAsSpam.perform_later(ip)
      redirect_back fallback_location: { action: :index }, notice: "#{count} accounts by #{ip} being marked as spam..."
    end

    def stats
      labels, datasets = User.daily_signups
      json = { labels: labels, datasets: datasets.collect { |name,values| { name: name, type: 'bar', values: values } } }
      render json: json.to_json
    end

    private

    def permitted_params
      params.permit(:filter_by)
    end

    def set_user
      @user = User.with_deleted.find_by_login(params[:id])
    end
  end
end
