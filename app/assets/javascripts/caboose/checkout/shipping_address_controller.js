
var ShippingAddressController = function(params) { this.init(params); };

ShippingAddressController.prototype = {

  cc: false,
  model_binder: false,
      
  init: function(params)
  {
    var that = this;
    for (var i in params)
      that[i] = params[i];
  },
    
  print: function()
  {
    var that = this;
    
    if (that.cc.all_downloadable())
    {
      $('#shipping_address_container').empty().append(div);
      return;
    }
    
    that.being_edited = false;
    var sa = that.cc.invoice.shipping_address;    
    
    var div = $('<div/>').append($('<h3/>').html('Shipping Address'));
            
    if (that.cc.is_empty_address(sa))
      div.append($('<p/>').append('[Empty]'));
    else
    {
      var name = sa ? sa.first_name + ' ' + sa.last_name : '';
      if (name.length == 0) name = '[Empty name]';
      var address = sa && sa.address1.length > 0 ? sa.address1 : '[Empty address]'
      var city_state_zip = sa ? (sa.city && sa.city.length > 0 ? sa.city : '[Empty city]') + ', ' + 
        (sa.state && sa.state.length > 0 ? sa.state : '[Empty state]') + ' ' + 
        (sa.zip && sa.zip.length > 0 ? sa.zip : '[Empty zip]') : ''; 
      
                                                       div.append($('<span/>').addClass('name'           ).html(name           )).append($('<br/>'));
      if (sa && sa.company && sa.company.length > 0)   div.append($('<span/>').addClass('company'        ).html(sa.company     )).append($('<br/>'));
                                                       div.append($('<span/>').addClass('address1'       ).html(address        )).append($('<br/>'));
      if (sa && sa.address2 && sa.address2.length > 0) div.append($('<span/>').addClass('address2'       ).html(sa.address2    )).append($('<br/>'));
                                                       div.append($('<span/>').addClass('city_state_zip' ).html(city_state_zip )).append($('<br/>'));
    }
    
    div.append($('<p/>').append($('<a/>').attr('href', '#').html('Edit').click(function(e) { e.preventDefault(); that.cc.refresh_and_print(); })));              
    $('#shipping_address_container').empty().append(div);
    if (that.cc.invoice.instore_pickup) $('#shipping_address_container').css('display', 'none');
  },
  
  edit: function()
  {
    var that = this;
    
    if (that.cc.all_downloadable())
    {
      $('#shipping_address_container').empty().append(div);
      return;
    }
    
    var sa = that.cc.invoice.shipping_address;
    if (!sa.id) sa.id = 1;
    
    var div = $('<div/>')
      .append($('<h3/>').html('Shipping Address'))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_first_name' ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_last_name'  ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_company'    ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_address1'   ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_address2'   ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_city'       ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_state'      ))
      .append($('<div/>').attr('id', 'shippingaddress_' + sa.id + '_zip'        ));          
    $('#shipping_address_container').empty().append(div);
    if (that.cc.invoice.instore_pickup) $('#shipping_address_container').css('display', 'none');
    
    that.model_binder = new ModelBinder({
      name: 'ShippingAddress',
      id: sa.id,
      update_url: '/checkout/shipping-address',
      authenticity_token: that.cc.authenticity_token,
      attributes: [                                                                                                  
        { name: 'first_name'  , wrapper_class: 'first_name' , nice_name: 'First Name'  , type: 'text'     , value: sa.first_name , width:  '50%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.first_name = this.value; that.cc.print_ready_message(); }}, 
        { name: 'last_name'   , wrapper_class: 'last_name'  , nice_name: 'Last Name'   , type: 'text'     , value: sa.last_name  , width:  '50%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.last_name  = this.value; that.cc.print_ready_message(); }}, 
        { name: 'company'     , wrapper_class: 'company'    , nice_name: 'Company'     , type: 'text'     , value: sa.company    , width: '100%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.company    = this.value; that.cc.print_ready_message(); }}, 
        { name: 'address1'    , wrapper_class: 'address1'   , nice_name: 'Address 1'   , type: 'text'     , value: sa.address1   , width: '100%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.address1   = this.value; if (this.value != this.value_old) { that.cc.refresh_cart(function() { that.cc.print_ready_message(); }); } else { that.cc.print_ready_message(); } }}, 
        { name: 'address2'    , wrapper_class: 'address2'   , nice_name: 'Address 2'   , type: 'text'     , value: sa.address2   , width: '100%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.address2   = this.value; if (this.value != this.value_old) { that.cc.refresh_cart(function() { that.cc.print_ready_message(); }); } else { that.cc.print_ready_message(); } }}, 
        { name: 'city'        , wrapper_class: 'city'       , nice_name: 'City'        , type: 'text'     , value: sa.city       , width:  '25%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.city       = this.value; if (this.value != this.value_old) { that.cc.refresh_cart(function() { that.cc.print_ready_message(); }); } else { that.cc.print_ready_message(); } }},
        { name: 'zip'         , wrapper_class: 'zip'        , nice_name: 'Zip'         , type: 'text'     , value: sa.zip        , width:  '25%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.zip        = this.value; if (this.value != this.value_old) { that.cc.refresh_cart(function() { that.cc.print_ready_message(); }); } else { that.cc.print_ready_message(); } }},
        { name: 'state'       , wrapper_class: 'state'      , nice_name: 'State'       , type: 'select'   , value: sa.state      , width:  '25%' , fixed_placeholder: false , before_update: function() { this.value_old = this.value_clean; }, after_update: function() { that.cc.invoice.shipping_address.state      = this.value; if (this.value != this.value_old) { that.cc.refresh_cart(function() { that.cc.print_ready_message(); }); } else { that.cc.print_ready_message(); } }, options_url: '/checkout/state-options', show_empty_option: true, empty_text: '-- State --' }                  
      ]            
    });            
  },
  
  ready_error: function()
  {
    var that = this;    
    if (that.cc.allow_instore_pickup && that.cc.invoice.instore_pickup) return null;
    if (that.cc.all_downloadable()) return null;
    if (that.cc.is_empty_address(that.cc.invoice.shipping_address))    
      return "Please enter your shipping address";
    
    var sa = that.cc.invoice.shipping_address;    
    if (!sa.first_name || sa.first_name.length == 0) return "Please enter your shipping address first name";
    if (!sa.last_name  || sa.last_name.length  == 0) return "Please enter your shipping address last name";
    if (!sa.address1   || sa.address1.length   == 0) return "Please enter your shipping address";
    if (!sa.city       || sa.city.length       == 0) return "Please enter your shipping address city";
    if (!sa.state      || sa.state.length      == 0) return "Please enter your shipping address state";
    if (!sa.zip        || sa.zip.length        == 0) return "Please enter your shipping address zip";

    return null;
  }
};
