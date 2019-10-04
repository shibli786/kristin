require "kristin/version"
require 'open-uri'
require "net/http"
require "spoon"

module Kristin
  class Converter
    def initialize(source, target, options = {},docker_options={})
      @options = options
      @source = source
      @target = target
      @docker_options = docker_options
      # @destination_path = docker_options[:mountable_dir_path].present? ? docker_options[:mountable_dir_path] : "/tmp"
    end

    def convert
      raise IOError, "Can't find pdf2htmlex executable in PATH" if not command_available?
      src = determine_source(@source)
      opts = process_options.split(" ")
      args = [pdf2htmlex_command, opts, src, @target].flatten
      pid = Spoon.spawnp(*args)
      Process.waitpid(pid)
      
      ## TODO: Grab error message from pdf2htmlex and raise a better error
      raise IOError, "Could not convert #{src}" if $?.exitstatus != 0

    end

    private

    def process_options
      opts = []
      @options.each do |key,value|
        if key.to_s.length == 1
         opts.push(["-#{key.to_s}",value].join(" "))
        else
          opts.push(["--#{key.to_s.split("_").join('-')}",value].join(" "))
        end
      end
      opts.join(" ")
    end

    def command_available?
      pdf2htmlex_command
    end

    def pdf2htmlex_command
      cmd = nil
      # cmd = "pdf2htmlex" if which("pdf2htmlex")
      # cmd = "pdf2htmlEX" if which("pdf2htmlEX")
      cmd = run_docker if cmd.blank? && docker_available? 
      cmd
    end

    def run_docker
      # `alias pdf2htmlExDocker="sudo docker run -t  -v /tmp:/tmp  -v #{destination_path}:/pdf2htmlEx 16a71a928414 pdf2htmlEX"`
      command("docker pull #{docker_image}:latest")
      "sudo docker run -t  -v /tmp:/tmp  -v #{destination_path}:/pdf2htmlEX #{docker_image} pdf2htmlEX"
    end

    def docker_available?
      docker_command
    end

    def docker_command
      cmd = nil
      cmd = "docker" if which("docker")
    end

    def destination_path
      @docker_options[:mountable_dir_path]
    end

    def docker_image
       @docker_options[:image_name]
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          end
        end
      return nil
    end


    def random_source_name
      rand(16**16).to_s(16)
    end

    def download_file(source)
      tmp_file = "/tmp/#{random_source_name}.pdf"
      File.open(tmp_file, "wb") do |saved_file|
        open(URI.encode(source), 'rb') do |read_file|
          saved_file.write(read_file.read)
        end
      end
      tmp_file
    end

    def determine_source(source)
      is_file = File.exists?(source) && !File.directory?(source)
      is_http = URI(source).scheme == "http"
      is_https = URI(source).scheme == "https"
      raise IOError, "Source (#{source}) is neither a file nor an URL." unless is_file || is_http || is_https
    
      is_file ? source : download_file(source)
    end
  end

  def self.convert(source, target, options = {},docker_options={})
    Converter.new(source, target, options,docker_options).convert
  end
end
