$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'streamer'
require 'queue'

require 'rubygems'
require 'gtk2'
require 'grooveshark'

module Squalo
  class Gui
    def initialize
      @grooveshark = Grooveshark::Client.new
      @streamer = Streamer.new
      @queue = SongQueue.new
      initialize_gui
    end

    def initialize_gui
      # The main window
      @window = Gtk::Window.new("Squalo")
      @window.border_width = 2
      @window.set_default_size(400, 289)

      @window.signal_connect("delete_event") { false }
      @window.signal_connect("destroy") do
        @streamer.stop
        Gtk.main_quit
      end

      # Playback control buttons
      @previous_button = Gtk::ToolButton.new(Gtk::Stock::MEDIA_PREVIOUS)
      @previous_button.sensitive = false
      @previous_button.signal_connect("clicked") { previous_button_clicked }

      @next_button = Gtk::ToolButton.new(Gtk::Stock::MEDIA_NEXT)
      @next_button.sensitive = false
      @next_button.signal_connect("clicked") { next_button_clicked }

      @pause_button = Gtk::ToolButton.new(Gtk::Stock::MEDIA_PLAY)
      @pause_button.sensitive = false
      @pause_button.signal_connect("clicked") { pause_button_clicked }

      # Now playing information
      @now_playing_label = Gtk::Label.new
      @now_playing_label.ellipsize = Pango::ELLIPSIZE_END

      # Queue ListStore                (index,  name,   artist, album)
      @queue_store = Gtk::ListStore.new(Fixnum, String, String, String)

      # Queue Columns
      name_column = Gtk::TreeViewColumn.new("Name", Gtk::CellRendererText.new, {:markup => 1})
      name_column.resizable = true
      name_column.expand = true
      name_column.sizing = Gtk::TreeViewColumn::FIXED
      name_column.min_width = 100

      artist_column = Gtk::TreeViewColumn.new("Artist", Gtk::CellRendererText.new, {:markup => 2})
      artist_column.resizable = true
      artist_column.sizing = Gtk::TreeViewColumn::FIXED
      artist_column.min_width = 100

      album_column = Gtk::TreeViewColumn.new("Album", Gtk::CellRendererText.new, {:markup => 3})
      album_column.resizable = true
      album_column.sizing = Gtk::TreeViewColumn::FIXED
      album_column.min_width = 100

      # Queue TreeView itself
      queue_treeview = Gtk::TreeView.new(@queue_store)
      queue_treeview.append_column(name_column)
      queue_treeview.append_column(artist_column)
      queue_treeview.append_column(album_column)
      queue_treeview.headers_visible = true
      queue_treeview.enable_search = true
      queue_treeview.search_column = 1

      # Search ListStore                (index,  name,   artist, album)
      @search_store = Gtk::ListStore.new(Fixnum, String, String, String)

      # Search Columns
      name_column = Gtk::TreeViewColumn.new("Name", Gtk::CellRendererText.new, {:text => 1})
      name_column.resizable = true
      name_column.expand = true
      name_column.sizing = Gtk::TreeViewColumn::FIXED
      
      artist_column = Gtk::TreeViewColumn.new("Artist", Gtk::CellRendererText.new, {:text => 2})
      artist_column.resizable = true
      artist_column.sizing = Gtk::TreeViewColumn::FIXED
      artist_column.min_width = 100
      
      album_column = Gtk::TreeViewColumn.new("Album", Gtk::CellRendererText.new, {:text => 3})
      album_column.resizable = true
      album_column.sizing = Gtk::TreeViewColumn::FIXED
      album_column.min_width = 100
      
      search_treeview = Gtk::TreeView.new(@search_store)
      search_treeview.append_column(name_column)
      search_treeview.append_column(artist_column)
      search_treeview.append_column(album_column)
      search_treeview.headers_visible = true
      search_treeview.enable_search = true
      search_treeview.search_column = 1
      search_treeview.signal_connect("row-activated") {|treeview, path, column| search_row_activated(path)}

      # Search entry
      @search_button = Gtk::Button.new("Search")
      @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
      @search_button.signal_connect("clicked") { search_button_clicked }

      @search_entry = Gtk::Entry.new
      @search_entry.signal_connect("activate") { @search_button.clicked }

      # Notebook tab labels
      @queue_tab_label = Gtk::Label.new("Queue")
      queue_tab_image = Gtk::Image.new("emblem-sound", Gtk::IconSize::SMALL_TOOLBAR)

      search_tab_label = Gtk::Label.new("Search")
      search_tab_image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::SMALL_TOOLBAR)

      # Layout
      control_box = Gtk::HBox.new
      control_box.pack_start(@previous_button, false)
      control_box.pack_start(@pause_button, false)
      control_box.pack_start(@next_button, false)
      control_box.pack_start(@now_playing_label, true, true, 5)

      queue_scroll_window = Gtk::ScrolledWindow.new
      queue_scroll_window.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
      queue_scroll_window.add(queue_treeview)

      search_scroll_window = Gtk::ScrolledWindow.new
      search_scroll_window.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
      search_scroll_window.add(search_treeview)

      search_entry_box = Gtk::HBox.new
      search_entry_box.pack_start(@search_entry, true, true, 2)
      search_entry_box.pack_start(@search_button, false, false, 2)

      search_page_box = Gtk::VBox.new
      search_page_box.pack_start(search_entry_box, false, false, 2)
      search_page_box.pack_start(search_scroll_window)

      queue_tab_box = Gtk::HBox.new
      queue_tab_box.pack_start(queue_tab_image)
      queue_tab_box.pack_start(@queue_tab_label)
      queue_tab_box.show_all

      search_tab_box = Gtk::HBox.new
      search_tab_box.pack_start(search_tab_image)
      search_tab_box.pack_start(search_tab_label)
      search_tab_box.show_all

      notebook = Gtk::Notebook.new
      notebook.tab_pos = Gtk::POS_BOTTOM
      notebook.append_page(queue_scroll_window, queue_tab_box)
      notebook.append_page(search_page_box, search_tab_box)
      notebook.show_all
      notebook.page = 1

      box = Gtk::VBox.new
      box.pack_start(control_box, false)
      box.pack_start(notebook)

      @window.add(box)
    end

    def run
      @window.show_all
      Gtk.main
    end
  end
end
