#!/usr/bin/env ruby

require 'rubygems'
require 'gtk2'
require 'grooveshark'

class Application
  def initialize
    initialize_ui
    @grooveshark = Grooveshark::Client.new
    @searching = false
    @search_thread = nil
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
    @artist_label = Gtk::Label.new

    # URL, Name, Artist, Album
    @queue_model = Gtk::ListStore.new(String, String, String, String)

    name_column = Gtk::TreeViewColumn.new("Name", Gtk::CellRendererText.new, {:text => 1})
    name_column.resizable = true
    name_column.expand = true
    artist_column = Gtk::TreeViewColumn.new("Artist", Gtk::CellRendererText.new, {:text => 2})
    artist_column.resizable = true
    album_column = Gtk::TreeViewColumn.new("Album", Gtk::CellRendererText.new, {:text => 3})
    album_column.resizable = true
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
    artist_column = Gtk::TreeViewColumn.new("Artist", Gtk::CellRendererText.new, {:text => 2})
    artist_column.resizable = true
    album_column = Gtk::TreeViewColumn.new("Album", Gtk::CellRendererText.new, {:text => 3})
    album_column.resizable = true
    search_treeview = Gtk::TreeView.new(@search_model)
    search_treeview.append_column(name_column)
    search_treeview.append_column(artist_column)
    search_treeview.append_column(album_column)
    search_treeview.headers_visible = true
    search_treeview.enable_search = true
    search_treeview.search_column = 1

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
    queue_scroll.height_request = 200
    queue_scroll.width_request = 400
    queue_scroll.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    queue_scroll.add(queue_treeview)

    search_scroll = Gtk::ScrolledWindow.new
    search_scroll.height_request = 200
    search_scroll.width_request = 400
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
      iter.set_value(0, song.id)
      iter.set_value(1, song.name)
      iter.set_value(2, song.artist)
      iter.set_value(3, song.album)
    end
    @search_button.label = "Search"
    @search_button.image = Gtk::Image.new(Gtk::Stock::FIND, Gtk::IconSize::BUTTON)
    @search_entry.sensitive = true
    @searching = false
  end

  def test
    @song_label.set_markup("<b>Still Alive</b>")
    @artist_label.set_markup("Jonathan Coulton, Ellen McLain")
    iter = @queue_model.append
    iter.set_value(1, "American Pie")
    iter.set_value(2, "Don McLean")
    iter.set_value(3, "American Pie")
    (1..20).each do |i|
      iter = @queue_model.append
      iter.set_value(1, i.to_s)
      iter.set_value(2, i.to_s)
      iter.set_value(3, i.to_s)
    end
  end

  def run
    @window.show_all
    Gtk.main
  end
end

app = Application.new
app.test
app.run
