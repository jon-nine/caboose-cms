module Caboose
  class CartController < Caboose::ApplicationController
    
    # @route GET /cart
    def index
    end
    
    # @route GET /cart/items
    def list
      render :json => @invoice.as_json(
        :include => [        
          { 
            :line_items => { 
              :include => { 
                :variant => { 
                  :include => [
                    { :product_images => { :methods => :urls }},
                    { :product => { :include => { :product_images => { :methods => :urls }}}}
                  ],
                  :methods => :title
                }
              }
            }
          },
          { :invoice_packages => { :include => [:shipping_package, :shipping_method] }},
          :customer,
          :shipping_address,
          :billing_address,
          :invoice_transactions,
          { :discounts => { :include => :gift_card }}
        ]        
      )
    end
    
    # @route GET /cart/item-count
    def item_count
      render :json => { :item_count => @invoice.item_count }            
    end
    
    # @route POST /cart
    def add      
      v = Variant.find(params[:variant_id])
      qty = params[:quantity] ? params[:quantity].to_i : 1

      vl = @invoice && @invoice.customer ? @invoice.customer.max_variant_quantity_allowed(v.id) : 99999999
      
      resp = StdClass.new
      
      if @invoice.line_items.exists?(:variant_id => v.id)
        li = @invoice.line_items.find_by_variant_id(v.id)
        old_qty = li.quantity
        requested_qty = old_qty + qty
        new_qty = (vl <= 0) ? 0 : ( requested_qty > vl ? vl : requested_qty )
        li.quantity = new_qty
        li.subtotal = li.unit_price * new_qty
        InvoiceLog.create(
          :invoice_id     => @invoice.id,
          :line_item_id   => li.id,
          :user_id        => logged_in_user.id,
          :date_logged    => DateTime.now.utc,
          :invoice_action => InvoiceLog::ACTION_LINE_ITEM_UPDATED,
          :field          => 'quantity',
          :old_value      => old_qty,
          :new_value      => new_qty
        )
      else
        unit_price = v.clearance && v.clearance_price ? v.clearance_price : (v.on_sale? ? v.sale_price : v.price)
        vlqty = (vl <= 0) ? 0 : ( qty > vl ? vl : qty ) # quantity added to cart is the max allowed for this user & variant
        li = LineItem.create(
          :invoice_id   => @invoice.id,
          :variant_id => v.id,
          :quantity   => vlqty,
          :unit_price => unit_price,
          :subtotal   => unit_price * vlqty,
          :status     => 'pending'
        )        
        InvoiceLog.create(
          :invoice_id     => @invoice.id,
          :line_item_id   => li.id,
          :user_id        => logged_in_user.id,
          :date_logged    => DateTime.now.utc,
          :invoice_action => InvoiceLog::ACTION_LINE_ITEM_CREATED                                                                          
        )
      end
      GA.delay(:queue => 'caboose_store').event(@site.id, 'cart', 'add', "Product #{v.product.id}, Variant #{v.id}")
      
      resp.success = true
      resp.item_count = @invoice.item_count
      render :json => resp
    end
    
    # @route PUT /cart/:line_item_id
    def update            
      resp = Caboose::StdClass.new
      li = LineItem.find(params[:line_item_id])

      save = true    
      fields_to_log = ['quantity', 'is_gift', 'include_gift_message', 'gift_message', 'gift_wrap', 'hide_prices']            
      params.each do |name,value|
        if fields_to_log.include?(name)        
          InvoiceLog.create(
            :invoice_id     => @invoice.id,
            :line_item_id   => li.id,
            :user_id        => logged_in_user.id,
            :date_logged    => DateTime.now.utc,
            :invoice_action => InvoiceLog::ACTION_LINE_ITEM_UPDATED,
            :field          => name,
            :old_value      => li[name.to_sym],
            :new_value      => value
          )            
        end
        case name
          when 'quantity'    then
            vl = li.invoice.customer.max_variant_quantity_allowed(li.variant_id)
            value = value.to_i
            new_qty = (vl <= 0) ? 0 : ( value > vl ? vl : value )
            if new_qty != li.quantity
              op = li.invoice_package
              if op
                op.shipping_method_id = nil
                op.total = nil
                op.save
              end
              if li.invoice
                li.invoice.shipping = 0.00
                li.invoice.save
                li.invoice.calculate        
              end
            end
            li.quantity = new_qty
            if li.quantity == 0
              li.destroy
              InvoiceLog.create(
                :invoice_id     => @invoice.id,
                :line_item_id   => li.id,
                :user_id        => logged_in_user.id,
                :date_logged    => DateTime.now.utc,
                :invoice_action => InvoiceLog::ACTION_LINE_ITEM_DELETED                
              )
            else            
              li.subtotal = li.unit_price * li.quantity
              li.save
              li.invoice.calculate
            end
          when 'is_gift'               then li.is_gift              = value
          when 'include_gift_message'  then li.include_gift_message = value
          when 'gift_message'          then li.gift_message         = value
          when 'gift_wrap'             then li.gift_wrap            = value
          when 'hide_prices'           then li.hide_prices          = value                                  
        end
      end
      li.save
      li.invoice.reload # Reload invoice in case li.quantity changed
      li.invoice.calculate
      resp.success = true
      render :json => resp                                    
    end
    
    # @route DELETE /cart/:line_item_id
    def remove                  
      li = LineItem.find(params[:line_item_id]).destroy
      InvoiceLog.create(
        :invoice_id     => @invoice.id,
        :line_item_id   => params[:line_item_id],
        :user_id        => logged_in_user.id,
        :date_logged    => DateTime.now.utc,
        :invoice_action => InvoiceLog::ACTION_LINE_ITEM_DELETED                
      )
      op = li.invoice_package
      if op
        op.shipping_method_id = nil
        op.total = nil
        op.save                
      end
      if li.invoice
        li.invoice.shipping = 0.00
        li.invoice.save
        li.invoice.calculate        
      end
      render :json => { :success => true, :item_count => @invoice.line_items.count }
    end
    
    # @route POST /cart/gift-cards
    def add_gift_card      
      resp = StdClass.new
      code = params[:code].strip
      gc = GiftCard.where("lower(code) = ?", code.downcase).first
                  
      if gc.nil? then resp.error = "Invalid gift card code."                    
      elsif gc.status != GiftCard::STATUS_ACTIVE                                then resp.error = "That gift card is not active."
      elsif gc.date_available && DateTime.now.utc < gc.date_available           then resp.error = "That gift card is not active yet."         
      elsif gc.date_expires && DateTime.now.utc > gc.date_expires               then resp.error = "That gift card is expired."
      elsif gc.card_type == GiftCard::CARD_TYPE_AMOUNT && gc.balance <= 0       then resp.error = "That gift card has a zero balance." 
      elsif gc.min_invoice_total && @invoice.total < gc.min_invoice_total             then resp.error = "Your invoice must be at least $#{sprintf('%.2f',gc.min_invoice_total)} to use this gift card." 
      elsif Discount.where(:invoice_id => @invoice.id, :gift_card_id => gc.id).exists? then resp.error = "That gift card has already been applied to this invoice."
      else            
        # Create the discount and recalculate the invoice
        d = Discount.create(:invoice_id => @invoice.id, :gift_card_id => gc.id, :amount => 0.0)
        d.calculate_amount                
        @invoice.calculate  
        
        resp.success = true
        resp.invoice_total = @invoice.total
        GA.delay(:queue => 'caboose_store').event(@site.id, 'giftcard', 'add', "Giftcard #{gc.id}")
      end
      render :json => resp
    end
    
    # @route DELETE /cart/discounts/:discount_id
    def remove_discount
      Discount.find(params[:discount_id]).destroy
      @invoice.calculate
      render :json => { :success => true }
    end
  end
end
