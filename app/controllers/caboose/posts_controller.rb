module Caboose
  class PostsController < ApplicationController
    
    helper :application
     
    # @route GET /posts/:id
    # @route GET /posts/:year/:month/:day/:slug
    def show
      
      # Make sure we're not under construction or on a forwarded domain
      return if under_construction_or_forwarding_domain?
      
      if params[:id]
        @post = Post.where(:id => params[:id]).first
     #   render :layout => "caboose/application"
      else      
        # Find the page with an exact URI match        
        uri = "/posts/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}"
        @post = Post.where(:site_id => @site.id, :uri => uri).first
      #  render :layout => "caboose/application"
      end      
      render :file => "caboose/extras/error404" and return if @post.nil?                 

      @editing = false
      @preview = false
      @post = Caboose.plugin_hook('post_content', @post)
    end
  
    #=============================================================================
    # Admin actions
    #=============================================================================
    
    # @route_priority 100
    # @route GET /admin/posts
    def admin_index
      return if !user_is_allowed('posts', 'view')
      render :layout => 'caboose/admin'           
    end

    # @route GET /admin/posts/json
    def admin_json
      return if !user_is_allowed('posts', 'view')
      pager = PageBarGenerator.new(params, {
          'site_id'     => @site.id,
          'title_like'  => '',
      },
      {
          'model'       => 'Caboose::Post',
          'sort'        => 'created_at',
          'desc'        => true,
          'base_url'    => '/admin/posts',
          'items_per_page' => 50,
          'use_url_params' => false,
          'additional_where' => [ "(site_id = #{@site.id})" ]
      })
      render :json => {
        :pager => pager,
        :models => pager.items.as_json()        
      }
    end
    
    # @route GET /admin/posts/:id/json
    def admin_json_single
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)
      render :json => @post
    end
    
    # @route GET /admin/posts/:id/preview
    def admin_edit_preview
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)     
      render :layout => 'caboose/admin'
    end

    # @route GET /admin/posts/:id/publish
    def admin_publish
      return unless user_is_allowed('posts', 'edit')
      post = get_edit_post(params[:id], @site.id)
      post.publish
      redirect_to "/admin/posts/#{post.id}/content"
    end

    # @route GET /admin/posts/:id/revert
    def admin_revert
      return unless user_is_allowed('posts', 'edit')
      post = get_edit_post(params[:id], @site.id)
      post.revert
      redirect_to "/admin/posts/#{post.id}/content"
    end
    
    # @route GET /admin/posts/:id/content
    def admin_edit_content
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)
      if @post.body
        @post.preview = @post.body
        @post.body = nil
        @post.save
      end
      if @post.block.nil?      
        redirect_to "/admin/posts/#{@post.id}/layout"
        return
      end
      Caboose::Block.where(:post_id => @post.id, :new_sort_order => nil).update_all('new_sort_order = sort_order') if @post && !@post.id.nil?
      Caboose::Block.where(:post_id => @post.id, :status => nil).update_all(:status => 'published') if @post && !@post.id.nil?
      @editing = true
      @preview = false
    end

    # @route GET /admin/posts/:id/preview-post
    def admin_preview_post
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)
      @editing = true
      @preview = true
    end
    
    # @route GET /admin/posts/:id/categories
    def admin_edit_categories
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)
      @categories = PostCategory.where(:site_id => @site.id).reorder(:name).all
      if @categories.nil? || @categories.count == 0
        PostCategory.create(:site_id => @site.id, :name => 'General News')
        @categories = PostCategory.where(:site_id => @site.id).reorder(:name).all
      end
      render :layout => 'caboose/admin'
    end
    
    # @route GET /admin/posts/:id/layout
    def admin_edit_layout
      return unless user_is_allowed('posts', 'edit')      
      @post = get_edit_post(params[:id], @site.id)
      render :layout => 'caboose/admin'
    end
    
    # @route GET /admin/posts/:id/delete
    def admin_delete_form
      return if !user_is_allowed('posts', 'delete')
      @post = get_edit_post(params[:id], @site.id)
      render :layout => 'caboose/admin'
    end
    
    # @route GET /admin/posts/:id
    # @route GET /admin/posts/:id/edit
    def admin_edit_general
      return if !user_is_allowed('posts', 'edit')    
      @post = get_edit_post(params[:id], @site.id)
      @post.verify_custom_field_values_exist
      render :layout => 'caboose/admin'
    end
    
    # @route PUT /admin/posts/:id/layout
    def admin_update_layout
      return unless user_is_allowed('posts', 'edit')      
      bt = BlockType.find(params[:block_type_id])
      post = get_edit_post(params[:id], @site.id)
      Block.where(:post_id => post.id).destroy_all if post
      Block.create(:post_id => post.id, :block_type_id => params[:block_type_id], :name => bt.name) if post
      resp = Caboose::StdClass.new({
        'redirect' => "/admin/posts/#{params[:id]}/content"
      })
      render :json => resp
    end
  
    # @route PUT /admin/posts/:id
    def admin_update      
      return if !user_is_allowed('posts', 'edit')
      resp = Caboose::StdClass.new({'attributes' => {}})
      post = get_edit_post(params[:id], @site.id)
      save = true
      params.each do |name, value|    
        case name                      
          when 'site_id'    then post.site_id    = value.to_i
          when 'slug'       then post.set_slug_and_uri(value)                        
          when 'title'      then post.title      = value            
          when 'subtitle'   then post.subtitle   = value
          when 'author'     then post.author     = value
          when 'body'       then post.body       = value
          when 'preview'    then post.preview    = value
          when 'hide'       then post.hide       = value
          when 'image_url'  then post.image_url  = value
          when 'published'  then post.published  = value
          when 'created_at' then post.created_at = DateTime.strptime(value,'%m/%d/%Y')
          when 'updated_at' then post.updated_at = DateTime.parse(value)
        end
      end
      resp.success = save && post.save      
      render :json => resp
    end
    
    # @route POST /admin/posts/:id/image
    def admin_update_image
      return if !user_is_allowed('posts', 'edit')  
      resp = Caboose::StdClass.new
      post = get_edit_post(params[:id], @site.id)
      post.image = params[:image]            
      resp.success = post.save
      resp.attributes = { 'image' => { 'value' => post.image.url(:thumb) }}
      render :text => resp.to_json
    end

    # @route POST /admin/posts/:id/remove-image
    def admin_remove_image
      return unless user_is_allowed("posts", 'edit')
      resp = Caboose::StdClass.new   
      b = Post.find(params[:id])
      b.image_file_name = nil
      b.image_file_size = nil
      b.image_content_type = nil
      b.image_updated_at = nil
      resp.success = b.save
      render :json => resp    
    end
    
    # @route_priority 1
    # @route GET /admin/posts/new
    def admin_new
      return if !user_is_allowed('posts', 'new')  
      @new_post = Post.new  
      render :layout => 'caboose/admin'
    end
  
    # @route POST /admin/posts
    def admin_add
      return if !user_is_allowed('posts', 'add')
      resp = Caboose::StdClass.new({
        'error' => nil,
        'redirect' => nil
      })
      post = Post.new
      post.site_id = @site.id
      post.title = params[:title]                  
      post.published = false
      if post.title.blank?
        resp.error = 'A title is required.'      
      else
        post.save        
        post.set_slug_and_uri(post.title)
        bt = BlockType.where(:id => @site.default_layout_id).first
        Block.create(:post_id => post.id, :block_type_id => bt.id, :name => bt.name) if post && bt
        resp.redirect = "/admin/posts/#{post.id}"
      end
      render :json => resp
    end
    
    # @route GET /admin/posts/:id/add-to-category
    def admin_add_to_category
      return if !user_is_allowed('posts', 'edit')
      post = get_edit_post(params[:id], @site.id)
      cat_id = params[:post_category_id]
      if post && !PostCategoryMembership.exists?(:post_id => post.id, :post_category_id => cat_id)
        PostCategoryMembership.create(:post_id => post.id, :post_category_id => cat_id)
      end
      render :json => true      
    end
    
    # @route GET /admin/posts/:id/remove-from-category
    def admin_remove_from_category
      return if !user_is_allowed('posts', 'edit')
      post = get_edit_post(params[:id], @site.id)
      cat_id = params[:post_category_id]
      if post && PostCategoryMembership.exists?(:post_id => post.id, :post_category_id => cat_id)
        PostCategoryMembership.where(:post_id => post.id, :post_category_id => cat_id).destroy_all
      end
      render :json => true      
    end
    
    # @route DELETE /admin/posts/:id
    def admin_delete
      return if !user_is_allowed('posts', 'edit')
      post = get_edit_post(params[:id], @site.id)
      PostCategoryMembership.where(:post_id => post.id).destroy_all if post
      Post.where(:id => post.id).destroy_all if post
      render :json => { 'redirect' => '/admin/posts' }      
    end

    private

    def get_edit_post(post_id, site_id)
      post = Post.find(post_id)
      return post if post && (post.site_id == site_id || logged_in_user.is_super_admin?)
      return nil
    end
    
  end
end
