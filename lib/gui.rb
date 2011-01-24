$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'streamer'
require 'queue'

require 'rubygems'
require 'gtk2'
require 'grooveshark'
require 'cgi'
require 'yaml'
require 'fileutils'

module Squalo
  class Gui
    def initialize
      # TODO: Stop hard-coding this
      @configuration_path = File.expand_path("~/.config/squalo/squalo.yaml")
      @configuration = {}
      load_configuration
      @streamer = Streamer.new
      @streamer.on_eos { on_eos }
      @queue = SongQueue.new
      initialize_gui
      Thread.new do
        @grooveshark = Grooveshark::Client.new
        @search_button.sensitive = true
        @search_entry.sensitive = true
      end

      @searching = false
      @search_thread = nil
      @search_results = []
    end

    def load_configuration
      if File.exists? @configuration_path
        File.open(@configuration_path, "r") do |f|
          @configuration = YAML.load(f)
        end
      end
    end

    def save_configuration
      if !File.exists? @configuration_path
        FileUtils.mkdir_p(File.dirname(@configuration_path))
      end
      File.open(@configuration_path, "w") do |f|
        YAML.dump(@configuration, f)
      end
    end

    def play_song(song)
      if song == nil
        @streamer.stop
        @now_playing_label.markup = ""
        @window.title = "Squalo"
        return
      end
      begin
        url = @grooveshark.get_song_url(song)
      rescue NoMethodError
        @grooveshark = Grooveshark::Client.new
        retry
      end
      @streamer.stream(url)
      @now_playing_label.markup = "<b>#{CGI.escapeHTML(song.name)}</b>\n<small>by</small> #{CGI.escapeHTML(song.artist)} <small>from</small> #{CGI.escapeHTML(song.album)}"
      @window.title = "#{song.name} by #{song.artist} - Squalo"
    end

    def search
      @searching = true
      update_search_buttons
      @search_results = @grooveshark.search_songs(@search_entry.text)
      @search_store.clear
      @search_results.each_with_index do |song, index|
        iter = @search_store.append
        iter[0] = index
        iter[1] = song.name
        iter[2] = song.artist
        iter[3] = song.album
      end
      @searching = false
      update_search_buttons
    end

    def on_eos
      play_song(@queue.next)
      update_control_buttons
      update_queue_store
    end

    def window_delete
      @configuration[:window_width] = @window.size[0]
      @configuration[:window_height] = @window.size[1]
      false
    end

    def window_destroy
      @streamer.stop
      save_configuration
      Gtk.main_quit
    end

    def update_control_buttons
      @previous_button.sensitive = @queue.has_previous? && @streamer.playing?
      @pause_button.sensitive = @streamer.playing?
      @pause_button.image = Gtk::Image.new((@streamer.paused?) ? Gtk::Stock::MEDIA_PLAY : Gtk::Stock::MEDIA_PAUSE, Gtk::IconSize::LARGE_TOOLBAR)
      @next_button.sensitive = @queue.has_next? && @streamer.playing?
    end

    def update_search_buttons
      if @searching
        @search_button.label = "Cancel"
        @search_button.image = Gtk::Image.new(Gtk::Stock::STOP, Gtk::IconSize::BUTTON)
        @search_entry.sensitive = false
      else
        @search_button.label = "Search"
        @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
        @search_entry.sensitive = true
      end
    end

    def update_queue_store
      @queue_store.clear
      @queue.songs.each_with_index do |song, index|
        iter = @queue_store.append
        iter[0] = index
        if index == @queue.current && @streamer.playing?
          iter[1] = "<b>#{CGI.escapeHTML(song.name)}</b>"
          iter[2] = "<b>#{CGI.escapeHTML(song.artist)}</b>"
          iter[3] = "<b>#{CGI.escapeHTML(song.album)}</b>"
        else
          iter[1] = CGI.escapeHTML(song.name)
          iter[2] = CGI.escapeHTML(song.artist)
          iter[3] = CGI.escapeHTML(song.album)
        end
      end
      songs_left = @queue.songs.length - @queue.current - 1
      @queue_tab_label.markup = (songs_left > 0) ? "Queue (#{songs_left})" : "Queue"
    end

    def previous_button_clicked
      play_song(@queue.previous)
      update_control_buttons
      update_queue_store
    end

    def pause_button_clicked
      (@streamer.paused?) ? @streamer.unpause : @streamer.pause
      update_control_buttons
    end

    def next_button_clicked
      play_song(@queue.next)
      update_control_buttons
      update_queue_store
    end

    def search_row_activated(path)
      row = @search_store.get_iter(path)
      song = @search_results[row[0]]
      @queue.enqueue(song)
      if !@streamer.playing?
        play_song(@queue.next)
      end
      update_control_buttons
      update_queue_store
    end

    def queue_row_activated(path)
      row = @queue_store.get_iter(path)
      play_song(@queue.skip_to(row[0]))
      update_control_buttons
      update_queue_store
    end

    def search_button_clicked
      if @searching
        @search_thread.kill
        @searching = false
        update_search_buttons
      else
        Thread.new { search }
      end
    end

    def initialize_gui
      # The main window
      @window = Gtk::Window.new("Squalo")
      @window.border_width = 2
      @window.set_default_size(@configuration[:window_width] || 400, @configuration[:window_height] || 289)

      @window.signal_connect("delete_event") { window_delete }
      @window.signal_connect("destroy") { window_destroy }

      # Playback control buttons
      @previous_button = Gtk::Button.new
      @previous_button.relief = Gtk::RELIEF_NONE
      @previous_button.image = Gtk::Image.new(Gtk::Stock::MEDIA_PREVIOUS, Gtk::IconSize::LARGE_TOOLBAR)
      @previous_button.sensitive = false
      @previous_button.signal_connect("clicked") { previous_button_clicked }

      @next_button = Gtk::Button.new
      @next_button.relief = Gtk::RELIEF_NONE
      @next_button.image = Gtk::Image.new(Gtk::Stock::MEDIA_NEXT, Gtk::IconSize::LARGE_TOOLBAR)
      @next_button.sensitive = false
      @next_button.signal_connect("clicked") { next_button_clicked }

      @pause_button = Gtk::Button.new
      @pause_button.relief = Gtk::RELIEF_NONE
      @pause_button.image = Gtk::Image.new(Gtk::Stock::MEDIA_PLAY, Gtk::IconSize::LARGE_TOOLBAR)
      @pause_button.sensitive = false
      @pause_button.signal_connect("clicked") { pause_button_clicked }

      # Now playing information
      @now_playing_label = Gtk::Label.new
      @now_playing_label.ellipsize = Pango::ELLIPSIZE_END
      @now_playing_label.xalign = 0

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
      queue_treeview.signal_connect("row-activated") {|treeview, path, column| queue_row_activated(path)}

      # Search ListStore                (index,  name,   artist, album)
      @search_store = Gtk::ListStore.new(Fixnum, String, String, String)

      # Search Columns
      name_column = Gtk::TreeViewColumn.new("Name", Gtk::CellRendererText.new, {:text => 1})
      name_column.resizable = true
      name_column.expand = true
      name_column.sizing = Gtk::TreeViewColumn::FIXED
      name_column.sort_column_id = 1
      
      artist_column = Gtk::TreeViewColumn.new("Artist", Gtk::CellRendererText.new, {:text => 2})
      artist_column.resizable = true
      artist_column.sizing = Gtk::TreeViewColumn::FIXED
      artist_column.min_width = 100
      artist_column.sort_column_id = 2
      
      album_column = Gtk::TreeViewColumn.new("Album", Gtk::CellRendererText.new, {:text => 3})
      album_column.resizable = true
      album_column.sizing = Gtk::TreeViewColumn::FIXED
      album_column.min_width = 100
      album_column.sort_column_id = 3

      dummy_column = Gtk::TreeViewColumn.new("")
      dummy_column.resizable = false
      dummy_column.sort_column_id = 0
      dummy_column.sort_indicator = false
      
      search_treeview = Gtk::TreeView.new(@search_store)
      search_treeview.append_column(dummy_column)
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
      @search_button.sensitive = false
      @search_button.signal_connect("clicked") { search_button_clicked }

      @search_entry = Gtk::Entry.new
      @search_entry.sensitive = false
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
