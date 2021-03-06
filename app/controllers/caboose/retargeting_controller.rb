require 'cgi'
require 'open-uri'
require 'httparty'

module Caboose
  class RetargetingController < ApplicationController
    layout 'caboose/admin'
      
    def before_action
      @page = Page.page_with_uri(request.host_with_port, '/admin')
    end
    
    # @route GET /admin/sites/:site_id/retargeting
    def admin_edit
      return if !user_is_allowed('sites', 'edit')       
      if !@site.is_master
        @error = "You are not allowed to manage sites."
        render :file => 'caboose/extras/error' and return
      end      
      @site = Site.find(params[:site_id])
    end
        
    # @route PUT /admin/sites/:id/retargeting
    def admin_update
      render :json => { :error => "You are not allowed to manage sites." } and return if !user_is_allowed('sites', 'edit') || !@site.is_master
      
      resp = StdClass.new     
      site = Site.find(params[:site_id])
      rc = site.retargeting_config
    
      params.each do |name,value|
        case name          
          when 'google_conversion_id'   then rc.google_conversion_id   = value    
          when 'google_labels_function' then rc.google_labels_function = value
          when 'fb_pixel_id'            then rc.fb_pixel_id            = value
          when 'fb_vars_function'       then rc.fb_vars_function       = value
    	  end
    	end
    	
    	resp.success = rc.save
    	render :json => resp
    end
    
  end
end
 