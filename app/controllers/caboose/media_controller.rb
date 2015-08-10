
module Caboose
  class MediaController < ApplicationController
    
    helper :application
    
    def before_action
      @page = Page.page_with_uri(request.host_with_port, '/admin')
    end    
    
    # GET /admin/media
    def admin_index
      return if !user_is_allowed('media', 'view')
      render :file => 'caboose/extras/error_invalid_site' and return if @site.nil?
                 
      config = YAML.load(File.read(Rails.root.join('config', 'aws.yml')))[Rails.env]      
      access_key = config['access_key_id']
      secret_key = config['secret_access_key']
      bucket     = config['bucket']
      bucket = Caboose::uploads_bucket && Caboose::uploads_bucket.strip.length > 0 ? Caboose::uploads_bucket : "#{bucket}-uploads"       
      policy = {        
        "expiration" => 1.hour.from_now.utc.xmlschema,
        "conditions" => [
          { "bucket" => bucket },          
          { "acl" => "public-read" },
          [ "starts-with", "$key", '' ],
          #[ "starts-with", "$Content-Type", 'image/' ],          
          [ 'starts-with', '$name', '' ], 	
          [ 'starts-with', '$Filename', '' ],          
        ]
      }
      @policy = Base64.encode64(policy.to_json).gsub(/\n/,'')      
      @signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha1'), secret_key, @policy)).gsub("\n","")
      @s3_upload_url = "https://#{bucket}.s3.amazonaws.com/"
      @aws_access_key_id = access_key                            
      
      id = params[:media_category_id]        
      @top_media_category = MediaCategory.top_category(@site.id)
      @media_category = id ? MediaCategory.find(id) : @top_media_category
      render :layout => 'caboose/admin'      
    end
    
    # GET /admin/media/json
    def admin_json
      return if !user_is_allowed('media', 'view')
      render :json => false and return if @site.nil?
      
      id = params[:media_category_id]        
      cat = id ? MediaCategory.find(id) : MediaCategory.top_category(@site.id)      
      render :json => cat.api_hash
    end

    # GET /admin/media/new
    def admin_new
      return unless user_is_allowed('media', 'add')
      @media_category_id = params[:media_category_id]             
      render :layout => 'caboose/admin'
    end
    
    # GET /admin/media/:id
    def admin_edit
      return unless user_is_allowed('media', 'edit')
      @media = Media.find(params[:id])
      render :layout => 'caboose/admin'
    end
    
    # GET /admin/media/:id/description
    def admin_edit_description
      return unless user_is_allowed('media', 'edit')
      @media = Media.find(params[:id])
      render :layout => 'caboose/modal'
    end
            
    # PUT /admin/media/:id
    def admin_update
      return unless user_is_allowed('media', 'edit')
      
      resp = StdClass.new({'attributes' => {}})
      m = Media.find(params[:id])
      
      save = true      
      params.each do |name, value|
        case name
          when 'name'         then m.name         = value
          when 'description'  then m.description  = value          
        end
      end
    
      resp.success = save && m.save
      render :json => resp
    end

    # POST /admin/media/edit-image
    def admin_edit_image
      new_url = params[:new_url]
      media_id = params[:media_id]
      resp = StdClass.new({'attributes' => {}})
      if !new_url.blank? && !media_id.blank?
        m = Media.find(media_id.gsub("image-",""))
        m.image = new_url
        m.save
        resp.success = "Saved image!"
      else
        resp.error = "Couldn't save image"
      end
      render :json => resp
    end
    
    # DELETE /admin/media/:id
    def admin_delete
      return unless user_is_allowed('media', 'delete')
      Media.find(params[:id]).destroy
      ProductImage.where(:media_id => params[:id]).destroy_all
      render :json => { :success => true }
    end
    
    # DELETE /admin/media/bulk
    def admin_bulk_delete
      return unless user_is_allowed('media', 'delete')      
      ids = params[:ids]
      if ids
        ids.each do |id|                
          Media.where(:id => id).destroy_all
          ProductImage.where(:media_id => id).destroy_all
        end
      end
      render :json => { :success => true }
    end
    
    # POST /admin/media/pre-upload
    def admin_pre_upload
      return unless user_is_allowed('media', 'view')
      media_category_id = params[:media_category_id]
      original_name = params[:name]
      name = Caboose::Media.upload_name(original_name)                        
      m = Media.where(:media_category_id => media_category_id, :original_name => original_name, :name => name).first
      if m.nil?
        m = Media.create(:media_category_id => media_category_id, :original_name => original_name, :name => name, :processed => false)
      end
      p = Product.where(:media_category_id => media_category_id).last
      if p
        pi = ProductImage.create(:product_id => p.id, :media_id => m.id)
      end
      render :json => { :success => true }
    end
    
  end
end
