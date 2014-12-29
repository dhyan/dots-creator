require "dots/creator/version"
require "dots/creator/dot_parser"

# require '/Users/narendrakumar/ruby_perls/dots/dots-creator/lib/dots/version.rb'
# require '/Users/narendrakumar/ruby_perls/dots/dots-creator/lib/dots/dot_parser.rb'
module Dots
  module Creator
    extend DotParser
    def self.get_data(kml)
      @kml = kml
      dot_density(@kml)
    end
  end
end

