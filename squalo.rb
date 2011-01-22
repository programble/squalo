#!/usr/bin/env ruby

require 'rubygems'
require 'gtk2'
require 'grooveshark'
require 'gst'

class Application
  def initialize
    initialize_ui
    @grooveshark = Grooveshark::Client.new
    @searching = false
    @search_thread = nil
    @pipeline = Gst::Pipeline.new
    @playing = false
    @pipeline.bus.add_watch do |bus, message|
      if message.type == Gst::Message::EOS
        @pipeline.stop
        @playing = false
        play_next_track
      end
      true
    end
  end

  def initialize_ui
    @window = Gtk::Window.new("Squalo")
    @window.signal_connect("delete_event") { false }
    # TODO: Stop playback
    @window.signal_connect("destroy") { Gtk.main_quit }
    @window.border_width = 2

    # TODO: Maybe we should not use ToolButton outside of Toolbar
    @pause_button = Gtk::ToolButton.new(Gtk::Stock::MEDIA_PLAY)
    @pause_button.sensitive = false

    @skip_button = Gtk::ToolButton.new(Gtk::Stock::MEDIA_NEXT)
    @skip_button.sensitive = false

    @song_label = Gtk::Label.new
    @song_label.ellipsize = Pango::ELLIPSIZE_END
    @artist_label = Gtk::Label.new
    @artist_label.ellipsize = Pango::ELLIPSIZE_END

    # URL, Name, Artist, Album
    @queue_model = Gtk::ListStore.new(String, String, String, String)

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
    
    queue_treeview = Gtk::TreeView.new(@queue_model)
    queue_treeview.append_column(name_column)
    queue_treeview.append_column(artist_column)
    queue_treeview.append_column(album_column)
    queue_treeview.headers_visible = true
    queue_treeview.enable_search = true
    queue_treeview.search_column = 1

    @search_model = Gtk::ListStore.new(String, String, String, String)
    
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
    
    search_treeview = Gtk::TreeView.new(@search_model)
    search_treeview.append_column(name_column)
    search_treeview.append_column(artist_column)
    search_treeview.append_column(album_column)
    search_treeview.headers_visible = true
    search_treeview.enable_search = true
    search_treeview.search_column = 1
    search_treeview.signal_connect("row-activated") {|treeview, path, column| add_to_queue(path) }

    @search_button = Gtk::Button.new("Search")
    @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
    @search_button.signal_connect("clicked") do
      if @searching
        @search_thread.kill
        @search_button.label = "Search"
        @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
        @search_entry.sensitive = true
        @searching = false
      else
        @search_button.label = "Cancel"
        @search_button.image = Gtk::Image.new(Gtk::Stock::STOP, Gtk::IconSize::BUTTON)
        @search_entry.sensitive = false
        @searching = true
        @search_thread = Thread.new { search }
      end
    end

    @search_entry = Gtk::Entry.new
    @search_entry.signal_connect("activate") { @search_button.clicked }

    np_box = Gtk::VBox.new
    np_box.pack_start(@song_label)
    np_box.pack_start(@artist_label)

    top_box = Gtk::HBox.new
    top_box.pack_start(@pause_button, false)
    top_box.pack_start(@skip_button, false)
    top_box.pack_start(np_box, true, true, 5)

    queue_scroll = Gtk::ScrolledWindow.new
    #queue_scroll.height_request = 200
    #queue_scroll.width_request = 400
    queue_scroll.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    queue_scroll.add(queue_treeview)

    search_scroll = Gtk::ScrolledWindow.new
    #search_scroll.height_request = 200
    #search_scroll.width_request = 400
    search_scroll.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    search_scroll.add(search_treeview)

    search_entry_box = Gtk::HBox.new
    search_entry_box.pack_start(@search_entry)
    search_entry_box.pack_start(@search_button, false)

    search_box = Gtk::VBox.new
    search_box.pack_start(search_entry_box, false)
    search_box.pack_start(search_scroll)

    #panes = Gtk::HPaned.new
    #panes.pack1(queue_scroll, true, false)

    notebook = Gtk::Notebook.new
    notebook.tab_pos = Gtk::POS_BOTTOM
    
    queue_tab_label = Gtk::HBox.new
    queue_tab_label.pack_start(Gtk::Image.new("emblem-sound", Gtk::IconSize::SMALL_TOOLBAR))
    queue_tab_label.pack_start(Gtk::Label.new("Queue"))
    queue_tab_label.show_all

    search_tab_label = Gtk::HBox.new
    search_tab_label.pack_start(Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::SMALL_TOOLBAR))
    search_tab_label.pack_start(Gtk::Label.new("Search"))
    search_tab_label.show_all

    notebook.append_page(queue_scroll, queue_tab_label)
    notebook.append_page(search_box, search_tab_label)

    vbox = Gtk::VBox.new
    vbox.pack_start(top_box, false)
    vbox.pack_start(notebook)

    @window.add(vbox)
  end

  def search
    @search_model.clear
    songs = @grooveshark.search_songs(@search_entry.text)
    songs.each do |song|
      iter = @search_model.append
      iter[0] = song.id
      iter[1] = song.name
      iter[2] = song.artist
      iter[3] = song.album
    end
    @search_button.label = "Search"
    @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
    @search_entry.sensitive = true
    @searching = false
  end

  def add_to_queue(path)
    song = @search_model.get_iter(path)
    iter = @queue_model.append
    iter[0] = song[0]
    iter[1] = song[1]
    iter[2] = song[2]
    iter[3] = song[3]
    play_next_track unless @playing
  end

  def play_next_track
    track = @queue_model.iter_first
    return unless track
    # TODO: Set now playing labels and buttons
    @song_label.label = track[1]
    @artist_label.label = track[2]
    url = @grooveshark.get_song_url_by_id(track[0])
    source = Gst::ElementFactory.make("souphttpsrc")
    source.location = url
    decoder = Gst::ElementFactory.make("mad")
    sink = Gst::ElementFactory.make("autoaudiosink")
    @pipeline.stop
    @pipeline.clear
    @pipeline.add(source, decoder, sink)
    source >> decoder >> sink
    # Not sure why @pipeline.play won't async itself
    Thread.new { @pipeline.play }
    @playing = true
    @queue_model.remove(track)
  end

  def run
    @window.show_all
    Gtk.main
  end
end

Gst.init
app = Application.new
app.run
