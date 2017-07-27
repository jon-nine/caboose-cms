 
var BlockContentController = function(params) { this.init(params); };

BlockContentController.prototype = {

  post_id: false,
  page_id: false,    
  new_block_type_id: false,
  selected_block_ids: [],
  blocks: false,
  assets_path: false,
  included_assets: false,
  mc: false,
  
  init: function(params)
  {
    var that = this;
    for (var i in params)
      that[i] = params[i];      
    that.refresh_blocks(function() {
      that.set_clickable();
    });
    that.mc = new ModalController({ parent_controller: this, assets_path: that.assets_path });
  },
  
  refresh_blocks: function(callback)
  {
    var that = this;
    $.ajax({
      url: that.base_url() + '/tree',
      type: 'get',
      success: function(resp) {
        that.blocks = resp;
        if (callback) callback();
      }
    });    
  },
    
  edit_block: function(block_id)
  {
    var that = this;
    var b = that.block_with_id(block_id);
    var bt = b.block_type;
    var ft = bt.field_type; // == 'image' || bt.field_type == 'file' ? 'media' : bt.field_type;
    
    var modal_controller = '';    
    if (bt.use_js_for_modal == true) { modal_controller = b.name ? b.name : bt.name; }      
    else if (ft == 'image')          { modal_controller = 'media';    }
    else if (ft == 'file')           { modal_controller = 'media';    }
    else if (ft == 'richtext')       { modal_controller = 'richtext'; }
    else                             { modal_controller = 'block';    }
        
    var new_modal_eval_string = "new " + that.underscores_to_camelcase(modal_controller) + "ModalController({ " +
      "  " + (that.page_id && that.page_id != null ? "page_id: " + that.page_id : "post_id: " + that.post_id) + ", " +
      "  block_id: " + block_id + ", " + 
      "  authenticity_token: '" + that.authenticity_token + "', " + 
      "  parent_controller: that, " +
      "  assets_path: '" + that.assets_path + "'" +
      "})";

    var js_file = 'caboose/block_modal_controllers/' + modal_controller + '_modal_controller.js';
    if (!that.mc.asset_included(js_file))    
    {
      // Include the file before instantiating the controller      
      $(document).on(modal_controller + '_modal_controller_loaded', function() { that.modal = eval(new_modal_eval_string); });
      that.mc.include_assets(js_file);                  
    }
    else // We're good, go ahead and instantiate
    {      
      that.modal = eval(new_modal_eval_string);                  
    }
  },
  
  underscores_to_camelcase: function(str)
  {
    var str2 = '';
    $.each(str.split('_'), function(j, word) { str2 += word.charAt(0).toUpperCase() + word.toLowerCase().slice(1); });
    return str2;
  },
      
  new_block: function(parent_id, before_block_id, after_block_id)
  {    
    var that = this;    
    var options = {      
      block_id: parent_id,
      authenticity_token: that.authenticity_token,
      parent_controller: this,      
      assets_path: that.assets_path,
      new_block_on_init: true,
      before_id: before_block_id,
      after_id: after_block_id
    }
    if (that.page_id && that.page_id != null) options['page_id'] = that.page_id;
    else                                      options['post_id'] = that.post_id;
    that.modal = new BlockModalController(options)
  },

  block_url: function(parent_id, b)
  {
    var that = this;    
    if (!b) return that.base_url() + '/' + parent_id;    
    return that.base_url(b) + '/' + b.id;     
  },

  create_block: function(block_type_id, parent_id, before_block_id, after_block_id, child_block_count) {
    var that = this;
    that.is_loading(true, 'Creating block...');
    var h = {                      
      authenticity_token: that.authenticity_token,
      block_type_id: block_type_id,
      before_id: before_block_id,
      after_id: after_block_id,
      child_count: child_block_count
    };
    $.ajax({
      url: that.block_url(parent_id, null),
      type: 'post',
      data: h,
      success: function(resp) {
        if (resp.error)   that.autosize("<p class='note error'>" + resp.error + "</p>");
        if (resp.success)
        {                    
          that.refresh_blocks(function() {
      //      that.edit_block(resp.new_id);
            that.render_blocks();            
          });
        }
      }
    });
  },

  is_loading: function(loading, message = 'Loading...') {
    var that = this;
    if ( loading == true )
      $("#caboose-loading").fadeIn().find('h4').text(message);
    else
      $("#caboose-loading").fadeOut();
  },


  move_block: function(block_id, parent_id, before_block_id, after_block_id) {
    var that = this;
    that.is_loading(true, 'Moving block...');
    var block_id = block_id.replace('block_','');
    var h = {                      
      authenticity_token: that.authenticity_token,
      parent_id: parent_id,
      before_id: before_block_id,
      after_id: after_block_id
    };
  //  console.dir(h);
    $.ajax({
      url: that.base_url() + '/' + block_id + '/move',
      type: 'post',
      data: h,
      success: function(resp) {
        if (resp.success)
        {                    
          that.refresh_blocks(function() {
            that.render_blocks();            
          });
        }
      }
    });
  },
  
  select_block: function(block_id)
  {            
    i = this.selected_block_ids.indexOf(block_id);
    if (i == -1) // Not there
    {
      this.selected_block_ids.push(block_id);
      $('#block_' + block_id).addClass('selected');
    }
    else
    {
      this.selected_block_ids.splice(i, 1);
      $('#block_' + block_id).removeClass('selected');
    }    
  },
  
  delete_block: function(block_id, confirm)
  {
    var that = this;      
    if (!confirm)
    {
      if (this.selected_block_ids.indexOf(block_id) == -1)
        this.selected_block_ids.push(block_id);
      var other_count = this.selected_block_ids.length - 1;
      
      var message = "Are you sure you want to delete this block";      
      if (other_count > 0)
        message += " and the " + other_count + " other selected block" + (other_count == 1 ? '' : 's');
      message += "?<br />";
      
      var p = $('<p/>')
        .addClass('caboose_note delete')
        .append(message)
        .append($('<input/>').attr('type', 'button').val('Yes').click(function(e) { e.preventDefault(); e.stopPropagation(); that.delete_block(block_id, true); })).append(" ")
        .append($('<input/>').attr('type', 'button').val('No').click(function(e) {  e.preventDefault(); e.stopPropagation(); that.render_blocks(); }));
      $('#block_' + block_id).attr('onclick','').unbind('click');
      $('#block_' + block_id).empty().append(p);
      return;
    }
    else {
      if ( this.selected_block_ids.length == 1 )
        that.is_loading(true, 'Deleting block...');
      else if (this.selected_block_ids.length > 1)
        that.is_loading(true, 'Deleting blocks...');
    }
    for (var i in this.selected_block_ids)
    {               
      $.ajax({
        url: that.base_url() + '/' + this.selected_block_ids[i],
        type: 'delete',
        async: false,
        success: function(resp) {}
      });
    }
    that.render_blocks();
  },
  
  // move_block_up: function(block_id)
  // {
  //   var that = this;
  //   this.loadify($('#block_' + block_id + '_move_up_handle span'));    
  //   $.ajax({
  //     url: that.base_url() + '/' + block_id + '/move-up',
  //     type: 'put',      
  //     success: function(resp) {        
  //       if (resp.success) that.render_blocks(function() { that.stop_loadify(); });      
  //     }
  //   });    
  // },
  
  // move_block_down: function(block_id)
  // {   
  //   var that = this;
  //   this.loadify($('#block_' + block_id + '_move_down_handle span'));
  //   $.ajax({
  //     url: that.base_url() + '/' + block_id + '/move-down',
  //     type: 'put',      
  //     success: function(resp) {        
  //       if (resp.success) that.render_blocks(function() { that.stop_loadify(); });      
  //     }
  //   });    
  // },

  duplicate_block: function(block_id)
  {
    var that = this;
    that.is_loading(true, 'Duplicating block...');
    that.loadify($('#block_' + block_id + '_duplicate_handle span'));    
    $.ajax({
      url: that.base_url() + '/' + block_id + '/duplicate',
      type: 'put',
      success: function(resp) {        
        if (resp.success) that.render_blocks(function() { that.stop_loadify(); });      
      }
    });    
  },
  
  loadify: function(el)
  {
    var that = this;
    if      (el.hasClass('ui-icon-arrowrefresh-1-e')) el.removeClass('ui-icon-arrowrefresh-1-e').addClass('ui-icon-arrowrefresh-1-s');
    else if (el.hasClass('ui-icon-arrowrefresh-1-s')) el.removeClass('ui-icon-arrowrefresh-1-s').addClass('ui-icon-arrowrefresh-1-w');
    else if (el.hasClass('ui-icon-arrowrefresh-1-w')) el.removeClass('ui-icon-arrowrefresh-1-w').addClass('ui-icon-arrowrefresh-1-n');
    else if (el.hasClass('ui-icon-arrowrefresh-1-n')) el.removeClass('ui-icon-arrowrefresh-1-n').addClass('ui-icon-arrowrefresh-1-e');
    else el.addClass('ui-icon-arrowrefresh-1-e');
    this.loadify_el = el;
    this.loadify_timer = setTimeout(function() { that.loadify(el); }, 200);                       
  },
  
  stop_loadify: function()
  {
    if (this.loadify_el)
    {
      this.loadify_el.removeClass('ui-icon-arrowrefresh-1-e')
        .removeClass('ui-icon-arrowrefresh-1-s')
        .removeClass('ui-icon-arrowrefresh-1-w')
        .removeClass('ui-icon-arrowrefresh-1-n');
    } 
    if (this.loadify_timer)
      clearTimeout(this.loadify_timer);                
  },
    
  /*****************************************************************************
  Block Rendering
  *****************************************************************************/
  
  render_blocks: function(before_render) 
  {
    var that = this;
    $('.sortable').sortable('destroy');
    var that = this;                
    $.ajax({
      url: that.base_url() + '/render-second-level',
      success: function(blocks) {        
        if (before_render) before_render();
        $(blocks).each(function(i, b) {
          $('#block_' + b.id).replaceWith(b.html);                              
        });
        that.refresh_blocks(function() { that.set_clickable(); });                
        that.selected_block_ids = [];
      }
    });
  },                                                                                                                               
         
  set_clickable: function()
  {
    var that = this;            
    var count = that.blocks.length;        
    $(that.blocks).each(function(i,b) {
      that.set_clickable_helper(b, false, false, (i == count-1));
    });
    that.is_loading(false);
  },
  
  set_clickable_helper: function(b, parent_id, parent_allows_child_blocks, is_last_child)
  {    
    var that = this;
    $('#block_' + b.id + ' *').attr('onclick', '').unbind('click');
    $('#block_' + b.id)
      .prepend($('<a/>').attr('id', 'block_' + b.id + '_drag_handle'      ).addClass('drag_handle'      ).append($('<span/>').addClass('ui-icon ui-icon-arrow-4'    )).click(function(e) { e.preventDefault(); e.stopPropagation();  }))
      .prepend($('<a/>').attr('id', 'block_' + b.id + '_select_handle'    ).addClass('select_handle'    ).append($('<span/>').addClass('ui-icon ui-icon-check'      )).click(function(e) { e.preventDefault(); e.stopPropagation(); that.select_block(b.id);    }))
      .prepend($('<a/>').attr('id', 'block_' + b.id + '_duplicate_handle' ).addClass('duplicate_handle' ).append($('<span/>').addClass('ui-icon ui-icon-copy'       )).click(function(e) { e.preventDefault(); e.stopPropagation(); that.duplicate_block(b.id); }))
      .prepend($('<a/>').attr('id', 'block_' + b.id + '_delete_handle'    ).addClass('delete_handle'    ).append($('<span/>').addClass('ui-icon ui-icon-close'      )).click(function(e) { e.preventDefault(); e.stopPropagation(); that.delete_block(b.id);    }));
    

    // empty post
    if ( $('.post-details-wrapper').length > 0 && b.block_type.allow_child_blocks == true && ((b.name == "content" && b.children.length == 0))) { // empty content area
      var text = 'post content area'
      $('#block_' + b.id).find('#empty_post_content').html($('<div/>')
        .addClass('new_block_link np')
        .append($('<div/>').addClass('new-page line').html('<p>Empty ' + text + '. Drag blocks here.</p>').droppable({
          hoverClass: "highlight",
          tolerance: "pointer",
          drop: function(event, ui) {
            if ( ui.draggable.attr('id') && ui.draggable.attr('id').indexOf('block_') == 0 )
              that.move_block(ui.draggable.attr('id'), b.id, null, null);
            else
              that.create_block(ui.draggable.data('btid'), b.id, null, null, ui.draggable.data('children'));
          }
        }))
      );
    }

    // empty page, grid, or text area
    else if (b.block_type.allow_child_blocks == true && ((b.name == "content" && b.children.length == 0) || (b.block_type.id == 3160 && b.children.length == 9 ) || (b.block_type.id == 422 && b.children.length == 6 ))) { // empty content area
      var text = b.name == 'content' ? 'content area' : (b.block_type.id == 422 ? 'text area' : 'column')
      $('#block_' + b.id).find('.content_body').html($('<div/>')
        .addClass('new_block_link np')
        .append($('<div/>').addClass('new-page line').html('<p>Empty ' + text + '. Drag blocks here.</p>').droppable({
          hoverClass: "highlight",
          tolerance: "pointer",
          drop: function(event, ui) {
            if ( ui.draggable.attr('id') && ui.draggable.attr('id').indexOf('block_') == 0 )
              that.move_block(ui.draggable.attr('id'), b.id, null, null);
            else
              that.create_block(ui.draggable.data('btid'), b.id, null, null, ui.draggable.data('children'));
          }
        }))
      );
    }

    $("#block_" + b.id).draggable( {
      handle: ".drag_handle",
      revert: "invalid",
      scroll: false,
      zIndex: 999,
      start: function(event, ui) { $(".line.ui-droppable").addClass('dropzone'); },
      stop: function(event, ui) { $(".line.ui-droppable").removeClass('dropzone'); }
    });

    if (parent_allows_child_blocks && (!b.name || b.name.length == 0) )
    {
      $('#block_' + b.id).before($('<div/>')          
        .addClass('new_block_link')
        .append($('<div/>').addClass('line').droppable({
          hoverClass: "highlight",
          tolerance: "pointer",
          drop: function(event, ui) {
            if ( ui.draggable.attr('id') && ui.draggable.attr('id').indexOf('block_') == 0 )
              that.move_block(ui.draggable.attr('id'), parent_id, b.id, null);
            else
              that.create_block(ui.draggable.data('btid'), parent_id, b.id, null, ui.draggable.data('children'));
          }
        }))
      );
      if (is_last_child && is_last_child == true)
      {
        $('#block_' + b.id).after($('<div/>')          
          .addClass('new_block_link')
          .append($('<div/>').addClass('line').droppable({
            hoverClass: "highlight",
            tolerance: "pointer",
            drop: function(event, ui) {
              if ( ui.draggable.attr('id') && ui.draggable.attr('id').indexOf('block_') == 0 )
                that.move_block(ui.draggable.attr('id'), parent_id, null, b.id);
              else
                that.create_block(ui.draggable.data('btid'), parent_id, null, b.id, ui.draggable.data('children'));
            }
          }))
        );
      }
    }
    $('#block_' + b.id).attr('onclick','').unbind('click');
    $('#block_' + b.id).click(function(e) {      
      e.preventDefault();
      e.stopPropagation();      
      that.edit_block(b.id); 
    });
    var show_mouseover = true;
    if (b.children && b.children.length > 0)
    {
      var count = b.children.length;
      $.each(b.children, function(i, b2) {
        if (b2.block_type.field_type == 'block' && b2.name != 'advanced_options' && b2.name != 'slide2' && b2.block_type.id != 3160 && b.block_type.id != 3159)
          show_mouseover = false;
        that.set_clickable_helper(b2, b.id, b.block_type.allow_child_blocks, i == (count-1));
      });            
    }
    if (show_mouseover)
    {
      $('#block_' + b.id).mouseover(function(el) { $('#block_' + b.id).addClass(   'block_over'); });
      $('#block_' + b.id).mouseout(function(el)  { $('#block_' + b.id).removeClass('block_over'); }); 
    }    
  },
  
  /*****************************************************************************
  Helper methods
  *****************************************************************************/
  
  block_with_id: function(block_id, b)
  {
    var that = this;                
    if (b && b.id == block_id)
      return b;
    var the_block = false;
    if ((!b && that.blocks) || (b && b.children))
    {
      $.each(b ? b.children : that.blocks, function(i, b2) {        
        the_block = that.block_with_id(block_id, b2);
        if (the_block)
          return false;
      });
    }
    return the_block;
  },
  
  base_url: function()
  {
    var that = this;
    return '/admin/' + (that.page_id && that.page_id != null ? 'pages/' + that.page_id : 'posts/' + that.post_id) + '/blocks';        
  }    
};

function toggle_blocks()
{
  $('#new_blocks_container2').slideToggle();
}
