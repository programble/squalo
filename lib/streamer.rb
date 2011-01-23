require 'gst'

module Squalo
  
  # A wrapper around Gstreamer's broken Ruby bindings
  class Streamer
    def initialize
      @playing = false
      @paused = false
      @pipeline = Gst::Pipeline.new
      # TODO: Handle this not existing
      @decoder = Gst::ElementFactory.make("mad")
      @sink = Gst::ElementFactory.make("autoaudiosink")
      @pipeline.bus.add_watch {|bus, message| watch(bus, message); true}
      @eos_callback = nil
    end

    def watch(bus, message)
      if message.type == Gst::Message::EOS
        @pipeline.stop
        @playing = false
        @eos_callback.call if @eos_callback
      end
    end

    def on_eos(&block)
      @eos_callback = block
    end
    
    def stream(url)
      source = Gst::ElementFactory.make("souphttpsrc")
      source.location = url
      
      @pipeline.stop
      @pipeline.clear
      @pipeline.add(source, @decoder, @sink)
      source >> @decoder >> @sink
      
      # Not even sure forking here is necessary
      Thread.new { @pipeline.play }
      
      @playing = true
      @paused = false
    end
    
    def playing?
      @playing
    end
    
    def paused?
      @paused
    end
    
    def pause
      if !paused? && playing?
        @pipeline.pause
        @paused = true
      end
    end
    
    def unpause
      if paused? && playing?
        @pipeline.play
        @paused = false
      end
    end

    def stop
      if playing?
        @pipeline.stop
        @playing = false
      end
    end
  end
end
          
