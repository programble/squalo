module Squalo
  class SongQueue
    attr_reader :songs, :current

    def initialize(songs=[])
      @songs = songs
      @current = nil
    end

    def skip_to(i)
      @current = i
      @songs[@current]
    end

    def has_next?
      @current != @songs.length - 1 && @songs.length > 0
    end

    def has_previous?
      @current && @current > 0
    end

    def next
      if has_next?
        @current += 1
        @songs[@current]
      elsif @current == nil && @songs.length > 0
        @current = 1
        @songs[@current]
      else
        @current = nil
      end
    end

    def previous
      if has_previous?
        @current -= 1
        @songs[@current]
      end
    end
  end
end

      
