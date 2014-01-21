
var PageContentController = function(page_id) { this.init(page_id); };

PageContentController.prototype = {

  page_id: false,    
  new_block_type_id: false,
  
  init: function(page_id)
  {
    this.page_id = page_id;
    var that = this;
    this.render_blocks(function() {
      that.sortable_blocks();
      that.draggable_blocks();
    });
  },
  
  sortable_blocks: function()
  { 
    var that = this;
    $('#pageblocks').sortable({      
      placeholder: 'sortable-placeholder',
      handle: '.sort_handle',
      receive: function(e, ui) {      
        that.new_block_type_id = ui.item.attr('id').replace('new_block_', '');    
      },
      update: function(e, ui) {        
        if (that.new_block_type_id)
        {
          $.ajax({
            url: '/admin/pages/' + that.page_id + '/blocks',
            type: 'post',
            data: { page_block_type_id: that.new_block_type_id, index: ui.item.index() },
            success: function(resp) { that.render_blocks(function() { that.edit_block(resp.block.id); }); }
          });                    
          that.new_block_type_id = false;
        }
        else
        {        
          $.ajax({
            url: '/admin/pages/' + that.page_id + '/block-order',
            type: 'put',
            data: $('#pageblocks').sortable('serialize', { key: "block_ids[]" }),
            success: function(resp) {}
          });
        }
      }
    });
  },
  
  draggable_blocks: function() 
  {
    $('#new_blocks li').draggable({
      dropOnEmpty: true,
      connectToSortable: "#pageblocks",
      helper: "clone",
      revert: "invalid"    
    });    
  },
    
  edit_block: function(block_id)
  {
    caboose_modal_url('/admin/pages/' + this.page_id + '/blocks/' + block_id + '/edit');    
  },
  
  delete_block: function(block_id, confirm)
  {
    var that = this;        
    if (!confirm)
    {
      var p = $('<p/>')
        .addClass('note warning')
        .append("Are you sure you want to delete the block? ")
        .append($('<input/>').attr('type', 'button').val('Yes').click(function() { that.delete_block(block_id, true); })).append(" ")
        .append($('<input/>').attr('type', 'button').val('No').click(function() { that.render_block(block_id); }));
      $('#pageblock_' + block_id).attr('onclick','').unbind('click');
      $('#pageblock_' + block_id).empty().append(p);
      return;
    }
    $.ajax({
      url: '/admin/pages/' + this.page_id + '/blocks/' + block_id,
      type: 'delete',
      success: function(resp) {
        that.render_blocks();      
      }
    });    
  },
    
  /*****************************************************************************
  Block Rendering
  *****************************************************************************/

  render_blocks: function(after)
  {
    $('#pageblocks').empty();    
    var that = this;
    $.ajax({      
      url: '/admin/pages/' + this.page_id + '/blocks/render?empty_text=[Empty, click to edit]',
      success: function(blocks) {
        $(blocks).each(function(i,b) {
          $('#pageblocks')
            .append($('<li/>')
              .attr('id', 'pageblock_container_' + b.id)                                          
              .append($('<a/>').attr('id', 'pageblock_' + b.id + '_sort_handle'  ).addClass('sort_handle'  ).append($('<span/>').addClass('ui-icon ui-icon-arrow-2-n-s')))
              .append($('<a/>').attr('id', 'pageblock_' + b.id + '_delete_handle').addClass('delete_handle').append($('<span/>').addClass('ui-icon ui-icon-close')).click(function(e) { e.preventDefault(); that.delete_block(b.id); }))
              .append($('<div/>').attr('id', 'pageblock_' + b.id).addClass('page_block'))
            );
        });                
        $(blocks).each(function(i,b) { that.render_block_html(b.id, b.html); });                        
        if (after) after();
      }
    });    
  },
  
  render_block: function(block_id, after)
  {    
    var that = this;
    $.ajax({
      url: '/admin/pages/' + this.page_id + '/blocks/' + block_id + '/render?empty_text=[Empty, click to edit]',
      success: function(html) {
        that.render_block_html(block_id, html);
        if (after) after();
      }
    });
  },
  
  render_block_html: function(block_id, html)
  {        
    var that = this;    
    $('#pageblock_' + block_id).empty().html(html);
    $('#pageblock_' + block_id).attr('onclick','').unbind('click');    
    $('#pageblock_' + block_id).click(function(e) { that.edit_block(block_id); });
  }        
};