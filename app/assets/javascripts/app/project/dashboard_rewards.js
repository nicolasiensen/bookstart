App.addChild('DashboardRewards', {
  el: '#dashboard-rewards-tab',

  events:{
    "cocoon:after-insert #rewards": "reloadSubViews"
  },

  activate: function() {
    this.$rewards = this.$('#dashboard-rewards #rewards');
    this.sortableRewards();
  },

  reloadSubViews: function(event, insertedItem) {
    this.rewardForm.undelegateEvents();
    this._rewardForm = null;
    this.rewardForm;
  },

  sortableRewards: function() {
    that = this;
    this.$rewards.sortable({
      axis: 'y',
      placeholder: "ui-state-highlight",
      start: function(e, ui) {
        return ui.placeholder.height(ui.item.height());
      },
      update: function(e, ui) {
        var csrfToken, position;
        position = that.$('#dashboard-rewards .reward-card').index(ui.item);
        csrfToken = $("meta[name='csrf-token']").attr("content");
        update_url = that.$(ui.item).find('.card-persisted').data('update_url');
        return $.ajax({
          type: 'POST',
          url: update_url,
          dataType: 'json',
          headers: {
            'X-CSRF-Token': csrfToken
          },
          data: {
            reward: {
              row_order_position: position
            }
          }
        });
      }
    })
  },

});

App.views.DashboardRewards.addChild('RewardForm', _.extend({
  el: '.reward-card',

  events: {
    'blur input' : 'checkInput',
    'submit form' : 'validate',
    "click #limit_reward": "showInput",
    "click .reward-close-button": "closeForm",
    "click .fa-question-circle": "toggleExplanation",
    "click .show_reward_form": "showRewardForm"
  },

  activate: function(){
    this.setupForm();
  },

  showInput: function(event) {
    var $target = this.$(event.currentTarget);
    $target.parent().parent().parent().next('.reward_maximum_contributions').toggle();
  },

  toggleExplanation: function(event) {
    event.preventDefault();
    var $target = this.$(event.currentTarget);
    $target.parent().next('.reward-explanation').toggle();
  },

  closeForm: function(event) {
    event.preventDefault();
    var $target = this.$(event.currentTarget);
    $target.closest('.card-edition').hide();
    $target.closest('.card-edition').parent().find('.card-persisted').show();
  },

  showRewardForm: function(event) {
    event.preventDefault();
    var $target = this.$(event.currentTarget);
    this.$($target.data('parent')).hide();
    this.$($target.data('target')).show();
  }

}, Skull.Form));
