# inspired from https://github.com/nbianca/discourse-favorites/blob/master/plugin.rb#L94-L119
class ConnecpathHelper::ListController < ::ListController

  def latest_by_categories
      list_opts = build_topic_list_options
      user = list_target_user

      selected_category_ids = params[:category_ids].split(',').map(&:to_i).compact

      list_opts[:exclude_category_ids] = get_excluded_category_ids(selected_category_ids)

      list = TopicQuery.new(user, list_opts).public_send("list_latest")

      list.more_topics_url = construct_url_with(:next, list_opts)
      list.prev_topics_url = construct_url_with(:prev, list_opts)

      respond_with_list(list)
  end

  private

  def get_excluded_category_ids(selected_ids = nil)
    exclude_categories = Category.all
    exclude_categories = exclude_categories.where.not(id: selected_ids) if selected_ids.present?
    exclude_category_ids = exclude_categories.pluck(:id)
    return exclude_category_ids
  end
end
