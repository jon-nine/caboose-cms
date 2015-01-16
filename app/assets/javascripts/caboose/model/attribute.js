
var Attribute = function(params) {
  for (var thing in params)
    this[thing] = params[thing];
  if (!this.text)
    this.text = this.value;
  this.value_clean = this.value;  
};

Attribute.prototype = {
  name: false,
  nice_name: false,
  type: false,
  value: false,
  value_clean: false,
  text: false,
  empty_text: 'empty',
  fixed_placeholder: true,
  align: 'left',
  before_update: false,
  after_update: false,
  before_cancel: false,
  after_cancel: false,
  debug: false,
  download_text: false,
  upload_text: false,
  image_refresh_delay: false,
  minute_increment: 15,
  hour_increment: 1,
  show_check_all: true,
  show_empty_option: false,  
  
  update_url: false,
  options_url: false,
  options: false,
  s3: false,
  
  save: function(after) {          
    if (this.before_update) this.before_update();    
    var this2 = this;
    $.ajax({
      url: this.update_url,
      type: 'put',
      data: this.name + '=' + encodeURIComponent(this.value),
			success: function(resp) {        			  
				if (resp.success)
				{
				  if (resp.attributes && resp.attributes[this2.name])
				    for (var thing in resp.attributes[this2.name])
				      this2[thing] = resp.attributes[this2.name][thing];				  
				  this2.value_clean = this2.value;
				}				
				if (after) after(resp);        				
				if (this2.after_update) this2.after_update();				
			},
			error: function() { 
			  if (after) after(false);
			}
		});
  },
  
  populate_options: function(after) {
    if (!this.options_url)
      return;        
    if (this.options)
    {
      if (after) after();
      return;
    }
    var this2 = this;
    $.ajax({
      url: this.options_url,
      type: 'get',
			success: function(resp) {
        this2.options = resp;
				if (after) after();
			},
			error: function() { 
			  if (after) after();
			}
		});
  }
};
