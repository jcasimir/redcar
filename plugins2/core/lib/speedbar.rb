
require 'singleton'

module Redcar
  class Speedbar
    def self.items
      @items
    end
    
    def self.append_item(item) #:nodoc:
      @items ||= []
      @items << item
    end
    
    def self.define_value_finder(name)
      self.class_eval %Q{
        def #{name}
          @speedbar_display.value(:#{name})
        end
        }
    end
    
    def self.label(text)
      append_item [:label, text]
    end
    
    def self.toggle(name, text, key)
      append_item [:toggle, name, text, key]
      define_value_finder(name)
    end
    
    def self.textbox(name)
      append_item [:textbox, name]
      define_value_finder(name)
    end
    
    def self.button(text, icon, key, &block)
      append_item [:button, text, icon, key, block]
    end
    
    attr_accessor :visible, :speedbar_display
    
    def show(tab)
      tab.gtk_speedbar.display(self)
    end
    
    def close
      if @visible
        @speedbar_display.close
      end
    end
  end
  
  class SpeedbarDisplay < Gtk::HBox
    attr_reader :visible, :spbar
    
    class << self
      attr_accessor :blocks
    end
    
    def initialize
      super
      spacing = 5
      @visible = false
      SpeedbarDisplay.blocks ||= {}
      @value = {}
    end
    
    def display(spbar)
      close if @visible
      @spbar = spbar
      @spbar.speedbar_display = self
      build_widgets
      open
    end
    
    def open
      @spbar.visible = true
      @visible = true
      @focus_widget.grab_focus
      Range.activate(@spbar.class)
      show_all
    end
    
    def close
      hide if visible
      @spbar.visible = false
      @visible = false
      bus("/redcar/keymaps/Speedbar").prune
      clear_children
      Range.deactivate(@spbar.class)
      @value = {}
    end
    
    def clear_children
      children.each {|child| remove(child)}
    end
    
    def build_widgets
      add_button nil, :CLOSE, "Escape" do
        self.close
      end
      add_key("Escape") { self.close }
      @focus_widget = nil
      @spbar.class.items.each do |item|
        send "add_#{item[0]}", *item[1..-1]
      end
    end
    
    def add_key(key, &block)
      @blocks ||= {}
      @blocks[key] = block
      com = Class.new(Redcar::Command)
      t = %Q{
        range #{@spbar.class.to_s}
        key "#{key}"

        def execute
          tab.gtk_speedbar.execute_key("#{key}")
        end
      }
      com.class_eval t
    end

    def execute_key(key)
      @blocks[key].call(@spbar) if @blocks[key]
    end
    
    def add_label(text)
      label = Gtk::Label.new(text)
      label.set_padding(5, 1)
      pack_start(label, false)
    end
    
    def add_toggle(name, text, key)
      toggle = Gtk::CheckButton.new(text)
      add_key(key) { toggle.active = !toggle.active? } if key
      @value[name] = fn { toggle.active }
      pack_start(toggle, false)
      @focus_widget ||= toggle
    end
    
    def add_textbox(name)
      e = Gtk::Entry.new
      # TODO: this should be set by preferences
      e.modify_font(Pango::FontDescription.new("Monospace 10"))
      @value[name] = fn { e.text }
      pack_start(e)
      @focus_widget ||= e
    end
    
    def add_button(text, icon, key, block=nil, &blk)
      raise "Two blocks given to Speedbar#add_button" if block and blk
      label = Gtk::HBox.new
      label.pack_start(i=Gtk::Icon.get_image(icon, Gtk::IconSize::MENU)) if icon
      label.pack_start(l=Gtk::Label.new(text)) if text
      b = Gtk::Button.new
      b.relief = Gtk::RELIEF_NONE
      b.child = label
      b.signal_connect("clicked") do
        if block
          block.call(@spbar)
        elsif blk
          blk.call(@spbar)
        end
      end
      add_key(key) { b.activate } if key
      pack_start(b, false)
      @focus_widget ||= b
    end
    
    def value(name)
      @value[name].call
    end
  end
end
