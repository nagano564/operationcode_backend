module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!, only: %i[update]

      def index
        render json: { user_count: User.count }, status: :ok
      rescue StandardError => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end

      def create
        user = User.new(user_params)

        if user.save
          UserMailer.welcome(user).deliver unless user.invalid?
          sign_in(user)
          render json: { token: user.token }
        else
          render json: user.errors, status: :unprocessable_entity
        end
      end

      def update
        if current_user.update_attributes(user_params)
          render json: current_user
        else
          render json: current_user.errors, status: :unprocessable_entity
        end
      end

      # For social media logins, renders the appropriate `redirect_to` path depending on whether the user is registered.
      #
      # Requires that the ActionController::Parameters contain a :user key, with a nested :email key.
      # For example: { user: { email: "john@example.com" } }
      #
      # @return [String] A string of the user's redirect_to path
      # @see https://github.com/zquestz/omniauth-google-oauth2#devise
      #
      def exist
        user = User.find_by(email: params.dig(:user, :email))
        redirect_path = '/profile'

        if user.nil?
          redirect_path = '/social_login'
        end
        render json: { redirect_to: redirect_path }
      end

      # For social media logins, creates the user in the database if necessary,
      # then logs them in, and renders the appropriate `redirect_to` path depending on whether the user is logging in
      # for the first time.
      #
      # @return [String] A string of the user's redirect_to path
      # @return [Json] A serialied JSON object derived from current_user
      # @return [Token] A token that the frontend stores to know the user is logged in
      # @see https://github.com/OperationCode/operationcode_backend/blob/master/app/controllers/api/v1/sessions_controller.rb#L8-L20
      #
      def social
          @user, redirect_path = User.fetch_social_user_and_redirect_path(params.dig(:user))

          if @user.save
            sign_in @user, event: :authenticate_user
            render json: {
              token: @user.token,
              user: UserSerializer.new(current_user),
              redirect_to: redirect_path
            }
          else
            redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
          end
      end

      def verify
        verified = IdMe.verify! params[:access_token]

        Rails.logger.debug "Got verified status '#{verified}'"
        Rails.logger.debug "Updating user'#{current_user.inspect}'"
        current_user.update_attribute(:verified, verified)
        Rails.logger.debug "Updating user'#{User.last.inspect}'"
        render json: { status: :ok, verified: verified }
      rescue => e
        Rails.logger.debug "When verifying User id #{User.last.id} through ID.me, experienced this error: #{e}"
        render json: { status: :unprocessable_entity }, status: :unprocessable_entity
      end

      def by_location
        render json: { user_count: UsersByLocation.new(params).count }, status: :ok
      rescue StandardError => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end

      private

      def user_params
        params.require(:user).permit(
          :email,
          :zip,
          :password,
          :mentor,
          :slack_name,
          :first_name,
          :last_name,
          :bio,
          :verified,
          :state,
          :address1,
          :address2,
          :username,
          :volunteer,
          :branch_of_service,
          :years_of_service,
          :pay_grade,
          :military_occupational_specialty,
          :github,
          :twitter,
          :linked_in,
          :employment_status,
          :education,
          :company_role,
          :company_name,
          :education_level,
          :scholarship_info,
          interests: []
        )
      end
    end
  end
end
