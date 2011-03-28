module Squalo
  class SongQueue
    attr_reader :current, :songs

    def initialize(songs=[])
      @songs = songs
      @current = nil
    end

    def enqueue(song)
      @songs << song
    end
    
    def clear
      @songs = []
      @current = nil
    end
    
    def remove(song)
      # TODO: Improve
      current = @songs[@current]
      @songs.delete_at(song)
      @current = @songs.find_index(current)
    end
    
    def move_up(song)
      current = @songs[@current]
      @songs[song], @songs[song - 1] = @songs[song - 1], @songs[song]
      @current = @songs.find_index(current)
    end
    
    def move_down(song)
      current = @songs[@current]
      @songs[song], @songs[song + 1] = @songs[song + 1], @songs[song]
      @current = @songs.find_index(current)
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
    
    def shuffle!
      if @songs.length > 1 && @current
        current = @songs.slice!(@current)
        @songs.shuffle!
        @songs.unshift(current)
        @current = 0
      end
    end
  end
end
