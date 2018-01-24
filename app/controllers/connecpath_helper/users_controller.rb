module ConnecpathHelper
  class UsersController < ApplicationController

    
    # def internal_request(path, params={})
    #   request_env = Rack::MockRequest.env_for(path, params: params.to_query)

    #   # Returns: [ status, headers, body ]
    #   Rails.application.routes.call(request_env)
    # end

    def forgot_password
      user = User.find_by_username_or_email(params[:login])
      user_presence = user.present? && user.id > 0 && !user.staged
      if user_presence
        email_token = user.email_tokens.create(email: user.email)
        Jobs.enqueue(:critical_user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
      end

      json = { result: "ok" }

      render json: json
    end

    def increment_custom_field
      result = {}
      result[:user_fields]=[]
      increment = (params["increment"])?(params["increment"].to_i):1
      if params[:user_id].kind_of?(Array)
        params[:user_id].each do |user_id|
          result[:user_fields] << increment_field(user_id,params[:key],increment)
        end
      elsif params[:user_id]
        result[:user_fields] << increment_field(params[:user_id],params[:key],increment)
      end
      render json: result
    end

    def increment_field(user_id,key,increment)
      field = UserCustomField.where(user_id: user_id).where(name: 'user_field_'+key.to_s).first
      if field
        initial = 0
        initial = field.value.to_i if field.value
        if field.update_attributes({value: initial+increment.to_i})
          puts true
        else
          puts false
        end
      else
        field = UserCustomField.new({user_id: user_id, name: 'user_field_'+key.to_s, value: 1})
        if field.save!
          puts true
        else
          puts false
        end
      end
      return field
    end



    def get_api_key

        puts "PARAMS"+params[:id].to_s
      if params[:id]
        user = User.where(id: params[:id]).last

        puts "USERR"+user.to_json
      end
      if(!user)
        render json: { errors: "user couldn't be found"}
      else
        puts "USERR"+user.to_json
        admin = User.where(admin: true).last
        api_key = ApiKey.where(user: user).first
        if !api_key
          api_key = ApiKey.create(user: user, key: SecureRandom.hex(32), created_by: admin)
        end
        avatar = UserAvatar.where(user: user).last
        puts avatar.to_json
        puts api_key.to_json
        response = {}
        response[:api_key] ={}
        response[:api_key][:id] = api_key.id
        response[:api_key][:key] = api_key.key
        response_params = {}
        response_params[:id] = user.id
        response_params[:avatar_template] = user.avatar_template 
        response_params[:username] = user.username
        response[:api_key][:user] =  response_params      
        render json: response
      end
      
      
     
    end

    def user_by_sendbird_id
      sendbird_id = params[:id]
      User.order(created_at: :desc).each do |user|
        if ((user.id>0)&&(user.user_fields["3"])&&(user.user_fields["3"] == sendbird_id) ) 
          puts user.name
          user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))
          user_params[:user_fields] = add_field_name(user.user_fields)
          break   
        end  
      end
      render json: user_params
    end

    def update_user_field
      if params[:login]
        login_info = params[:login]
        user = User.find_by_username_or_email(params[:login])
      elsif params[:id]
        user = User.where(id: params[:id]).last
      end
      if(!user)
        render json: { errors: "Login info couldn't be found"}
      else
        key = params[:field_key]
        value = params[:field_value]
        user.custom_fields['role']=value.to_s
        user.save!
        # fields = UserCustomField.where(user_id: user.id)
        # puts fields.to_json
        # fields.each do |field|
        #   if field['name'] == 'user_field_'+key.to_s
        #     field['value'] = value
        #     field.save!
        #   end
        # end
        # puts fields.to_json
        # puts field['user_field_'+key.to_s]=
        # user.user_fields['6']='ABCDEF'
        # user.save!
        puts user.user_fields
        new_user = User.where(id: user.id).last
        puts new_user.to_json
        user_params = (new_user.slice(:email, :active, :name, :username, :id, :created_at))      
        user_params[:user_fields] = add_field_name(new_user.user_fields)
        user_params[:result] = 'ok'
        render json: user_params 
      end
    end
    def user_details(arr)
      arr = arr.uniq
      user_expanded_list = {}
      arr.each do |id|
        user = User.where(id: id).first
        user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))      
        user_params[:user_fields] = add_field_name(user.user_fields)
        user_expanded_list[id.to_s] = user_params 
      end
      return user_expanded_list
    end

    def user_fields
      user_expanded_list = {}

      # puts params
      # puts params[:user_list]
      params[:user_list].each do |id|
        user = User.where(id: id).first
        user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))      
        user_params[:user_fields] = add_field_name(user.user_fields)
        user_expanded_list[id.to_s] = user_params 
      end
      render json: {id_stream: params.slice(:user_list), field_stream: user_expanded_list}
    end

    def user_fields_by_username
      arr = params[:user_list]
      puts arr
      arr = arr.uniq
      user_expanded_list = []
      # puts params
      # puts params[:user_list]
      # User.all.each do |user|
      #   puts user.username
      # end
      arr.each do |username|
        user = User.where(username: username).first
        if user
          puts username
          puts user.to_json
          user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))      
          user_params[:user_fields] = add_field_name(user.user_fields)
          user_expanded_list << user_params 
        end
      end
      render json: {username_stream: arr, field_stream: user_expanded_list}
    end

    def topic_list
      topic_expanded_list = []
      user_expanded_list = {}
      user_list = []

      page_num = (params.has_key?("page"))? (params["page"].to_i-1):(0)
      limit = (params.has_key?("limit"))? (params["limit"].to_i):(10)
      final_list = params[:topic_list].drop(page_num * limit).first(limit)
      # puts params
      # puts params[:topic_list]
      final_list.each do |id|
        topic = Topic.where(id: id).first
        topic_params = (topic.slice(:id, :title, :last_posted_at, :created_at, :posts_count, :user_id, :reply_count, :category_id, :participant_count))      
        
        topic_params["post_stream"] = []
        Post.where(topic: topic).order('post_number ASC').limit(2).each do |post|
          # puts post.to_json
          puts post.user_id
          user_list << post.user_id
          post_params = (post.slice(:id, :user_id, :post_number, :raw, :reply_count, :like_count, :created_at))   
          if params[:user_id]
            post_params[:current_user_liked] = false
            PostAction.where(post: post).each do |post_action|
              # puts post.to_json
              puts "Post Action"+post_action.to_json.to_s
              if post_action.user_id.to_i == params[:user_id].to_i
                post_params[:current_user_liked] = true
              end
            end
          end
          topic_params["post_stream"] << post_params 
        end
        topic_expanded_list << topic_params 
      end
      if user_list.count > 0
        user_expanded_list = user_details(user_list)
      end
      render json: {id_stream: params.slice(:topic_list), details_stream: topic_expanded_list, user_stream: user_expanded_list}
    end

    def topic_details
      topic_expanded_list = {}
      user_expanded_list = {}
      user_list = []
      topic = Topic.where(id: params[:id]).first
      if(topic)
        topic_params = (topic.slice(:id, :title, :last_posted_at, :created_at, :posts_count, :user_id, :reply_count, :category_id, :participant_count))      
        topic_expanded_list["details"] = topic_params 
        # topic_expanded_list["details"]["post_stream"] = []
        post_stream = []
        Post.where(topic: topic).order('post_number ASC').each do |post|
          
          puts "Current Post"+post.to_json.to_s
          post_params = (post.slice(:id, :user_id, :post_number, :raw, :reply_count, :like_count, :created_at, :reply_to_post_number, :user_deleted, :deleted_at, :deleted_by_id))   
          # puts params[:user_id]
          # puts "Current User"+params[:user_id].to_s
          if params[:user_id]
            post_params[:current_user_liked] = false
            PostAction.where(post: post).each do |post_action|
              # puts post.to_json
              # puts "Post Action"+post_action.to_json.to_s + (post_action.user_id.to_i == params[:user_id].to_i).to_s
              # puts "Post Action User"+post_action.user_id.to_s + (params[:user_id].to_s)
              if post_action.user_id.to_i == params[:user_id].to_i
                puts "Adding Current User Like"
                post_params[:current_user_liked] = true
              end
            end
          end

          post_stream << post_params 
        # post = Topic.where(id: id).first
        end
        puts (params.has_key?(:page))
        puts (params.has_key?(:limit))
        page_num = (params.has_key?("page"))? (params["page"].to_i-1):(0)
        limit = (params.has_key?("limit"))? (params["limit"].to_i):(10)
        puts "Page Number"+page_num.to_s
        puts "Limit"+limit.to_s
        result_list = post_stream.drop(page_num * limit).first(limit)
        result_list.each do |answer|
          user_list << answer["user_id"]
        end

        topic_expanded_list["details"]["post_stream"] = result_list
        total_count = (post_stream.count/limit).to_i
      end

      user_expanded_list = user_details(user_list)
      render json: { details_stream: topic_expanded_list, user_stream: user_expanded_list, page:page_num+1, limit: limit, total_page: total_count}
    end

    def replies_to_post

    end

    def mark_notification_as_read
      if params[:id]
        notification = Notification.where(id: params[:id]).first
        notification.read = true
        notification.save!

        render json: {success: true}
      else
        render json: {error: 'No id present'}
      end
    end

    def create_counselor_notification
      # Fetching Counselor Notification
      # post_number,topic_id,notification_type(8),user_id
      # data: topic_title,original_post_id, original_post_type(1), original_username, display_username
      # where('full_name LIKE :search OR code LIKE :search', search: "%#{search}%")
      post = Post.where(id: params[:post_id]).first
      puts post.to_json
      current_user = User.where(username: params[:username]).last
      user_h = User.all
      if current_user.user_fields["1"] == 'Student'
        # Announcement
        user_h.order(created_at: :desc).each do |user|
          if (preliminary_check(user)&&(user.user_fields["1"] == 'Counselor')&&(user.username != params[:username]) )  
            post_notification(post, user, 13)
          end 
        end
      else
        #  Question by student
        user_h.order(created_at: :desc).each do |user|
          if (preliminary_check(user)&&(user.user_fields["1"] == 'Student')&&(user.username != params[:username]) )  
            post_notification(post, user, 14)
          end 
        end
      end
      render json: {notified: true} 
    end

    def delete_notification
      if params.has_key?("id")
        # Deleting Notification by id
        Notification.find(params[:id]).destroy
      else
        # Deleting All Notification
        Notification.delete_all
      end

    end

    def device_token_list
      puts "Params Role"+ params["role"]
      token_list = []
      username_list = []
      user_id_list = []
      # where('full_name LIKE :search OR code LIKE :search', search: "%#{search}%")
      user_h = User.all
      user_h.order(created_at: :desc).each do |user|
        puts user.to_json
        if ((!user.admin)&&(user.id>0)&&(user.user_fields["1"] == params["role"])&&check_active_user(user) )    
          token_list << user.user_fields['4'] if user.user_fields['4']
          username_list << user.username if user.user_fields['4']
          user_id_list << user.id if user.user_fields['4']
        end  
      end
      render json: { token_list: token_list, username_list: username_list, user_id_list: user_id_list}
    end


    def unread_notif_list
      puts "Params Role"+ params["role"]
      token_list = []
      # where('full_name LIKE :search OR code LIKE :search', search: "%#{search}%")
      user_h = User.all
      user_h.order(created_at: :desc).each do |user|
        puts user.to_json
        if ((!user.admin)&&(user.id>0)&&(user.user_fields["1"] == params["role"])&&check_active_user(user) )    
          token_list << user.user_fields['16'] if user.user_fields['4']
        end  
      end
      render json: { user_list: token_list}
    end

    def post_notification(post, user, notification_type)
      data = {
        original_post_id: post.id,
        original_post_type: 1,
        topic_title: post.topic.title,
        category_id: post.topic.category.id,
        original_username: post.user.username,
        display_username: post.user.username,
        counselor: true
      }
      Notification.create(
        notification_type: notification_type,
        topic_id: post.topic_id,
        post_number: post.post_number,
        user_id: user.id,
        read: false,
        data: data.to_json
      )
    end

    def list
      puts "Params Role"+ params["role"]
      user_list = []
      # where('full_name LIKE :search OR code LIKE :search', search: "%#{search}%")
      user_h = User.all

      if params["query"]
        query = params["query"]
        user_h = User.where('name LIKE :search OR username LIKE :search', search: "%#{query}%")
      elsif params["name"]
        query = params["name"]
        user_h = User.where('name LIKE :search', search: "%#{query}%")
      end
      user_h.order(created_at: :desc).each do |user|
        puts user.to_json
        if ((!user.admin)&&(user.id>0)&&(user.user_fields["1"] == params["role"])&&check_active_user(user) ) 
          puts user.to_json
          user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))      
          user_params[:user_fields] = add_field_name(user.user_fields) 
          avatar = UserAvatar.where(user: user).first
          if avatar.custom_upload_id
            url = Upload.where(id: avatar.custom_upload_id).last.url
            user_params[:url] = url
          end     
          user_list << user_params    
        end  
      end 
      page_num = params["page"].to_i-1
      limit = params["limit"].to_i
      # puts "Page Number"+page_num.to_s
      # puts "Limit"+page_num.to_s
      result = user_list.drop(page_num * limit).first(limit)
      total_count = user_list.count
      render json: { total_count: total_count, user_list: result, role: params["role"], page: page_num+1, limit: limit}
    end

    def login_info
      if params[:login]
        login_info = params[:login]
        user = User.find_by_username_or_email(params[:login])
      elsif params[:id]
        user = User.where(id: params[:id]).last
      end
      if(!user)
        render json: { errors: "Login info couldn't be found"}
      else
        # puts user.to_json
        avatar = UserAvatar.where(user: user).last
        puts avatar.to_json
        user_params = (user.slice(:email, :active, :name, :username, :id, :created_at))      
        user_params[:user_fields] = add_field_name(user.user_fields)       
        render json: { user: user_params}
      end
    end

    # USERS
    def users_all
      user_list = []
      User.all.each do |user|
        puts user.to_json
        if ((!user.admin)&&(user.id>0))
          user_list << user.id
        end
      end
      render json: user_list.to_json
    end

    def delete_user
      User.where(id: params[:id]) do |user|
        user.delete
      end
      render json: {deleted: params[:id]}
    end

    def delete_all_users
      User.all.each do |user|
        if ((!user.admin)&&(user.id>0))
          user.delete
        end
      end
      render json: {deleted: true}
    end


    # POSTS
    def posts_all
      post_list = []
      Post.all.each do |post|
        post_list << post.id
      end
      render json: post_list.to_json
    end

    def delete_post
      Post.where(id: params[:id]) do |post|
        post.delete
      end
      render json: {deleted: params[:id]}
    end

    def delete_all_posts
      Post.all.each do |post|
        post.delete
      end
      render json: {deleted: true}
    end

    # Topics
    def topics_all
      topic_list = []
      Topic.all.each do |topic|
        topic_list << topic.id
      end
      render json: topic_list.to_json
    end

    def delete_topic
      Topic.where(id: params[:id]) do |topic|
        topic.delete
      end
      render json: {deleted: params[:id]}
    end

    def delete_all_topics
      Topic.all.each do |topic|
        topic.delete
      end
      render json: {deleted: true}
    end

    # Categories
    def categories_all
      category_list = []
      Category.all.each do |category|
        category_list << category.id
      end
      render json: category_list.to_json
    end

    def delete_category
      Category.where(id: params[:id]) do |category|
        category.delete
      end
      render json: {deleted: params[:id]}
    end

    def delete_all_categories
      Category.all.each do |category|
        category.delete
      end
      render json: {deleted: true}
    end

    def email_token
      email_token =''

      if params[:user_id]
        email_token = EmailToken.where(user_id: params[:user_id]).last
        user = User.where(id: params[:user_id]).last
      elsif params[:username]
        user = User.where(username: params[:username]).last
        email_token = EmailToken.where(user_id: user.id).last
      elsif params[:email]
        email_token = EmailToken.where(email: params[:email]).last
        user = User.where(email: params[:email]).last
      else
        email_token = EmailToken.last
      end
      if !email_token.confirmed && !email_token.expired
        render json: { success: true, email_token: email_token, username: user.username}
      else
        render json: {errors: "Email Token is not valid anymore. Kindly reset password again"}
      end
    end


    def activate_token
      if params[:username]
        user = User.where(username: params[:username]).last
      elsif params[:email]
        user = User.where(email: params[:email]).last
      else
        render json: { error: "No params found"}
      end
      if user
        activation_token = user.user_fields["6"]
        if activation_token 
          # Activate user with new password
          email_token = EmailToken.where(user_id: params[:user_id]).last
          EmailToken.confirm(token)
        end
      end
      render json: { email_token: email_token}
    end


    def sample
      user = User.first.user_fields
      render json: { name: "donut", description: "delicious!", user: user}
    end

    def create_post
      posts_controller = PostsController.new
      params = { created_at: "2017-09-23", raw: "Reply to 6 2017-09-262017-09-262017-09-262017-09-26", topic_id: 1,  reply_to_post_number: 6}
      # # posts_controller.request = params
      # # response = posts_controller.response
      # puts posts_controller.create(params).to_s
      # render json: JSON.parse(posts_controller.render(:create(params)))
    end
    # private
    #   def retrieve_user_info
    #     oauth_info = Oauth2UserInfo.find_by(user_id: current_user.id)
    #     response = RestClient.get(
    #       endpoint_store_url,
    #       {
    #         params: {
    #           user_uid: oauth_info.try(:uid),
    #           user_token: session[:authentication]
    #         }
    #       }
    #     )
    #     render json: response, status: :ok
    #   end

    #   def endpoint_store_url
    #     "#{SiteSetting.endpoint_url}/api/users/retrieve_user_info.json"
    #   end
    def check_active_user(user)
      active = true
      if user.user_fields['15'] && user.user_fields['15']== 'false'
        active = false
      end
      return active
    end

    def preliminary_check(user)
      return ((!user.admin)&&(user.id>0)&&check_active_user(user))
    end
    def add_field_name(params)
      fields = convert_to_h(params)
      @mapping  = {"1" => "role", "2" => "graduation_year", "3" => "sendbird_id", "4" => "device_token",
     "5" => "channel_url", "6" => "activation_token", "7" =>"head_counselor", "8" => "answers_by_bot",
      "9" => "answers_by_forum", "10" => "you_posted_to_forum", "11" => 'sendbird_broadcast_url', '12' => 'avatar_url',
      '13' => 'school_code', '14' => 'school_name', '15' => 'is_active', '16' => 'unread_notif_count'}
      fields = fields.map {|k, v| [@mapping[k], v] }.to_h
      return fields
    end

    def convert_to_h(params)
      second_params = params
      if params.class == ActionController::Parameters
        second_params =  Hash[params.to_unsafe_h.map{ |k, v| [k.to_sym, v] }]
      end
      return second_params
    end
  end
end
