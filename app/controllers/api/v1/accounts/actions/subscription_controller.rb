module Api::V1::Accounts::Actions
  class SubscriptionController < Api::V1::BaseController
    before_action :authenticate_with_token!
    before_action :set_account, only: [:pause, :resume, :cancel]

    # POST /accounts/1/actions/pause
    def pause
      authorize @account

      if @account.status == "paused"
        render_unprocessable_entity detail: "is already paused", source: {
          pointer: "/data/attributes/status" } and return
      end

      subscription = SubscriptionService.new({
        id: @account.billing.external_subscription_id
      }).delete

      if subscription
        if @account.update(status: "paused")
          render_meta status: "paused"
        else
          render_unprocessable_resource @account
        end
      else
        render_unprocessable_entity detail: "subscription is invalid", source: {
          pointer: "/data/attributes/billing" }
      end
    end

    # POST /accounts/1/actions/resume
    def resume
      authorize @account

      if @account.status == "active"
        render_unprocessable_entity detail: "is already active", source: {
          pointer: "/data/attributes/status" } and return
      end

      if @account.status != "paused"
        render_unprocessable_entity detail: "is not paused", source: {
          pointer: "/data/attributes/status" } and return
      end

      # Setting a trial allows us to continue to use the previously 'paused'
      # subscription's billing cycle
      previous_billing_cycle_end = @account.billing.external_subscription_period_end.to_i || nil
      subscription = SubscriptionService.new({
        customer: @account.billing.external_customer_id,
        trial: previous_billing_cycle_end,
        plan: @account.plan.external_plan_id
      }).create

      if subscription
        if @account.update(status: "active")
          render_meta status: "active"
        else
          render_unprocessable_resource @account
        end
      else
        render_unprocessable_entity detail: "subscription is invalid", source: {
          pointer: "/data/attributes/billing" }
      end
    end

    # POST /accounts/1/actions/cancel
    def cancel
      authorize @account

      if @account.status == "canceled"
        render_unprocessable_entity detail: "is already canceled", source: {
          pointer: "/data/attributes/status" } and return
      end

      subscription = SubscriptionService.new({
        id: @account.billing.external_subscription_id
      }).delete

      if subscription
        if @account.update(status: "canceled")
          render_meta status: "canceled"
        else
          render_unprocessable_resource @account
        end
      else
        render_unprocessable_entity detail: "subscription is invalid", source: {
          pointer: "/data/attributes/billing" }
      end
    end

    private

    def set_account
      @account = Account.find_by_hashid params[:account_id]
      @account || render_not_found
    end
  end
end
