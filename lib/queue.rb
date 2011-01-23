module Squalo
  class SongQueue
    attr_reader :songs, :current

    def initialize(songs=[])
      @songs = songs
      @current = nil
    end

    def enqueue(song)
      @songs << song
    end

    def skip_to(i)
      @current = i
      @songs[@current]
    end

    def has_next?
      @current == nil || (@current < @songs.length - 1 && @songs.length > 0)
    end

    def has_previous?
      @current && @current > 0
    end

    def next
      if has_next? && @current == nil
        puts "bob"
        @current = 0
        @songs[@current]
      elsif has_next?
        @current += 1
        @songs[@current]
      else
        nil
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
