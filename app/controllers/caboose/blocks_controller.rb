require 'nokogiri'

module Caboose
  class BlocksController < ApplicationController
    
    helper :application
    
    #===========================================================================
    # Admin actions
    #===========================================================================
    
    # GET /admin/pages/:page_id/blocks
    def admin_index
      return if !user_is_allowed('pages', 'view')
      blocks = Block.where(:page_id => params[:page_id]).reorder(:sort_order)
      render :json => blocks      
    end

    # GET /admin/pages/:page_id/blocks/:id/new
    # GET /admin/pages/:page_id/blocks/new
    def admin_new
      return unless user_is_allowed('pages', 'add')
                  
      if params[:id]
        block_type_id = params[:block_type_id]
        block_type_id = Block.find(params[:id]).block_type.default_child_block_type_id if block_type_id.nil?                 
        if block_type_id                                  
          b = Block.new
          b.page_id = params[:page_id].to_i
          b.parent_id = params[:id]
          b.block_type_id = block_type_id
          b.sort_order = Block.where(:parent_id => params[:id]).count              
          b.save
          b.create_children        
          redirect_to "/admin/pages/#{b.page_id}/blocks/#{b.id}/edit"
          return
        end
      end
    
      @page = Page.find(params[:page_id])
      @block = params[:id] ? Block.find(params[:id]) : Block.new(:page_id => params[:page_id])
      @after_id = params[:after_id] ? params[:after_id] : nil
      @before_id = params[:before_id] ? params[:before_id] : nil
      render :layout => 'caboose/modal'                
    end
    
    # GET /admin/pages/:page_id/blocks/:id
    def admin_show
      return unless user_is_allowed('pages', 'edit')      
      block = Block.find(params[:id])
      render :json => block      
    end
    
    # GET /admin/pages/:page_id/blocks/tree
    # GET /admin/pages/:page_id/blocks/:id/tree    
    def admin_tree
      return unless user_is_allowed('pages', 'edit')      
      
      blocks = []
      if params[:id]
        b = Block.find(params[:id])
        blocks << { 'id' => b.id, 'children' => admin_tree_helper(b), 'field_type' => b.block_type.field_type }
      else
        Block.where("parent_id is null and page_id = ?", params[:page_id]).reorder(:sort_order).all.each do |b|      
          blocks << { 'id' => b.id, 'allow_child_blocks' => b.block_type.allow_child_blocks, 'children' => admin_tree_helper(b), 'field_type' => b.block_type.field_type }
        end
      end
      render :json => blocks
    end        
      
    def admin_tree_helper(b)
      arr = []
      b.children.each do |b2|
        arr << { 'id' => b2.id, 'allow_child_blocks' => b2.block_type.allow_child_blocks, 'children' => admin_tree_helper(b2), 'field_type' => b2.block_type.field_type }
      end
      return arr
    end      
      
    # GET /admin/pages/:page_id/blocks/:id/render
    def admin_render
      return unless user_is_allowed('pages', 'edit')      
      b = Block.find(params[:id])      
      bt = b.block_type
      if bt.nil?
        bt = BlockType.where(:name => 'richtext').first 
        b.block_type_id = bt.id
        b.save
      end
      #b.create_children
      html = b.render(b, {
        :empty_text => params[:empty_text],
        :editing => true
      })
      render :json => html            
    end
    
    # GET /admin/pages/:page_id/blocks/render
    def admin_render_all
      return unless user_is_allowed('pages', 'edit')
      p = Page.find(params[:page_id])
      blocks = Block.where("page_id = ? and parent_id is null", p.id).reorder(:sort_order).collect do |b|
        #bt = b.block_type
        #if bt.nil?
        #  bt = BlockType.where(:name => 'richtext').first 
        #  b.block_type_id = bt.id
        #  b.save
        #end
        #b.create_children
        {
          :id => b.id,
          :block_type_id => b.block_type.id,
          :sort_order => b.sort_order,
          :html => b.render(b, {
            :empty_text => params[:empty_text],
            :editing => true
          })        
        }
      end
      render :json => blocks
    end
    
    # GET /admin/pages/:page_id/blocks/render-second-level
    def admin_render_second_level
      return unless user_is_allowed('pages', 'edit')
      p = Page.find(params[:page_id])
      @p = p
      blocks = p.block.children.collect do |b|
        {           
          :id => b.id,
          :block_type_id => b.block_type.id,
          :sort_order => b.sort_order,
          :html => b.render(b, {
            :view => nil,
            :controller_view_content => nil,
            :modal => false,
            :editing => true,
            :empty_text => params[:empty_text],            
            :css => '|CABOOSE_CSS|',                     
            :js => '|CABOOSE_JAVASCRIPT|',
            :csrf_meta_tags => '|CABOOSE_CSRF|',
            :csrf_meta_tags2 => '|CABOOSE_CSRF|',    
            :logged_in_user => @logged_in_user,
            :site => @site,
            :page => p
          })
        }
      end
      render :json => blocks
      #render :layout => false
      
      #respond_to do |format|        
      #  format.json
      #end
    end
    
    # GET /admin/pages/:page_id/blocks/:id/edit
    def admin_edit
      return unless user_is_allowed('pages', 'edit')
      @page = Page.find(params[:page_id])
      @block = Block.find(params[:id])
      @block.create_children
      @modal = true

      @document_domain = request.host
      @document_domain.gsub('http://', '')
      @document_domain.gsub('https://', '')

      begin        
        render "caboose/blocks/admin_edit_#{@block.block_type.full_name}", :layout => 'caboose/modal'
      rescue
        render :layout => 'caboose/modal'
      end
    end
    
    # GET /admin/pages/:page_id/blocks/:id/advanced
    def admin_edit_advanced
      return unless user_is_allowed('pages', 'edit')
      @page = Page.find(params[:page_id])
      @block = Block.find(params[:id])
      @block.create_children      
      render :layout => 'caboose/modal'      
    end
    
    # POST /admin/pages/:page_id/blocks
    # POST /admin/pages/:page_id/blocks/:id
    def admin_create
      return unless user_is_allowed('pages', 'add')

      resp = Caboose::StdClass.new({
          'error' => nil,
          'redirect' => nil
      })

      b = Block.new
      b.page_id = params[:page_id].to_i
      b.parent_id = params[:id] ? params[:id] : nil
      b.block_type_id = params[:block_type_id]
                      
      if !params[:index].nil?      
        b.sort_order = params[:index].to_i
        
        i = 1
        b.parent.children.where('sort_order >= ?', b.sort_order).reorder(:sort_order).all.each do |b3|
          b3.sort_order = b.sort_order + i
          b3.save
          i = i + 1                  
        end
        
      elsif params[:before_id]
        b2 = Block.find(params[:before_id].to_i)
        b.sort_order = b2.sort_order
        
        i = 1
        b2.parent.children.where('sort_order >= ?', b.sort_order).reorder(:sort_order).all.each do |b3|
          b3.sort_order = b.sort_order + i
          b3.save
          i = i + 1                  
        end
      
      elsif params[:after_id]
        b2 = Block.find(params[:after_id].to_i)
        b.sort_order = b2.sort_order + 1
        
        i = 1
        b2.parent.children.where('sort_order >= ?', b.sort_order).reorder(:sort_order).all.each do |b3|
          b3.sort_order = b.sort_order + i
          b3.save
          i = i + 1                  
        end
        
      elsif params[:id]
        b.sort_order = Block.where(:parent_id => params[:id]).count        
      end                  
      
      # Save the block
      b.save
      
      # Ensure that all the children are created for the block
      b.create_children
      
      # Set the global values if necessary
      if b.block_type.is_global        
        b.get_global_value(@site.id)
      end

      # Send back the response
      #resp.block = b
      resp.redirect = "/admin/pages/#{b.page_id}/blocks/#{b.id}/edit"
      render :json => resp
    end
    
    # PUT /admin/pages/:page_id/blocks/:id
    def admin_update
      return unless user_is_allowed('pages', 'edit')
      
      resp = StdClass.new({'attributes' => {}})
      b = Block.find(params[:id])

      save = true
      params.each do |k,v|
        case k
          #when 'page_id'       then b.page_id       = v
          when 'parent_id'     then 
            b.parent_id  = v
            b.sort_order = Block.where(:parent_id => v).count
          when 'block_type_id' then b.block_type_id = v
          when 'sort_order'    then b.sort_order    = v
          when 'constrain'     then b.constrain     = v
          when 'name'          then b.name          = v
          when 'value'         then
            
            if b.block_type.is_global
              if b.block_type.field_type == 'checkbox_multiple'
                b.value = Block.parse_checkbox_multiple_value(b, v)
              else                    
                b.value = v
              end                
              b.update_global_value(b.value, @site.id)              
            else              
              if Caboose::parse_richtext_blocks == true && b.block_type.field_type == 'richtext' && (b.name.nil? || b.name.strip.length == 0) && (b.block_type.name != 'richtext2')                
                b = RichTextBlockParser.parse(b, v, request.host_with_port)
              else
                if b.block_type.field_type == 'checkbox_multiple'
                  b.value = Block.parse_checkbox_multiple_value(b, v)
                else                    
                  b.value = v
                end
              end
            end
        end
      end
      
      # Trigger the page cache to be updated
      pc = PageCache.where(:page_id => b.page_id).first
      if pc
        pc.refresh = true
        pc.save
        PageCacher.delay.refresh
      else
        PageCacher.delay.cache(b.page_id)
      end
                
      resp.success = save && b.save
      b.create_children
      render :json => resp      
    end
    
    # POST /admin/pages/:page_id/blocks/:id/image
    def admin_update_image
      return unless user_is_allowed('pages', 'edit')
      
      resp = StdClass.new({'attributes' => {}})
      b = Block.find(params[:id])
      b.image = params[:value]
      b.save
      resp.success = true 
      resp.attributes = { 'value' => { 'value' => b.image.url(:tiny) }}
      
      render :json => resp
    end
    
    # POST /admin/pages/:page_id/blocks/:id/file
    def admin_update_file
      return unless user_is_allowed('pages', 'edit')
      
      resp = StdClass.new({'attributes' => {}})
      b = Block.find(params[:id])
      b.file = params[:value]
      b.save
      resp.success = true      
      resp.attributes = { 'value' => { 'value' => b.file.url }}
      
      render :json => resp
    end
    
    # DELETE /admin/pages/:page_id/blocks/:id
    def admin_delete
      return unless user_is_allowed('pages', 'delete')
      
      resp = StdClass.new
      b = Block.find(params[:id])
      parent_id = b.parent_id
      if b.parent_id
        resp.redirect = "/admin/pages/#{b.page_id}/blocks/#{b.parent_id}/edit"
      else
        resp.close = true
      end
      b.destroy
      
      if parent_id
        i = 0
        Block.where(:parent_id => parent_id).reorder(:sort_order).all.each do |b2|
          b2.sort_order = i
          b2.save
          i = i + 1
        end
      end

      render :json => resp
    end
    
    # PUT /admin/pages/:page_id/blocks/:id/move-up
    def admin_move_up
      return unless user_is_allowed('pages', 'delete')
      
      resp = StdClass.new
      b = Block.find(params[:id])
      changed = b.move_up
      if !changed
        resp.error = "The block is already at the top."
      else
        resp.success = "The block has been moved up successfully."
      end
        
      #if b.sort_order == 0
      #  resp.error = "The block is already at the top."
      #else
      #  b2 = nil
      #  
      #  new_sort_order = b.sort_order - 1
      #  while new_sort_order > 0 do
      #    b2 = Block.where("parent_id = ? and sort_order = ?", b.parent_id, new_sort_order).first
      #    break if b2
      #    new_sort_order = new_sort_order - 1
      #  end
      #  if b2
      #    b2.sort_order = new_sort_order + 1
      #    b2.save
      #  else
      #    new_sort_order = 1
      #  end
      #  b.sort_order = new_sort_order
      #  b.save
      #  resp.success = "The block has been moved up successfully."
      #end

      render :json => resp
    end
    
    # PUT /admin/pages/:page_id/blocks/:id/move-down
    def admin_move_down
      return unless user_is_allowed('pages', 'delete')
      
      resp = StdClass.new
      b = Block.find(params[:id])
      b2 = Block.where("parent_id = ? and sort_order = ?", b.parent_id, b.sort_order + 1).first
      if b2.nil?
        resp.error = "The block is already at the bottom."
      else        
        b2.sort_order = b.sort_order
        b2.save
        b.sort_order = b.sort_order + 1
        b.save
        resp.success = "The block has been moved down successfully."
      end

      render :json => resp
    end
		
  end
  
end
