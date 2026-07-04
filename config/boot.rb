ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
# NOTE: bootsnap is disabled because this project lives on a path containing
# non-ASCII characters ("Área de Trabalho"), which bootsnap's native file
# reader cannot open on Windows (raises Errno::ENOENT: bs_fetch:open_current_file).
# require "bootsnap/setup" # Speed up boot time by caching expensive operations.
