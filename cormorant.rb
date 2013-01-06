#!/usr/bin/env ruby
# coding: utf-8

require 'open-uri'
require 'digest/sha1'
require 'yaml'
require 'nokogiri'
require 'diffy'
require 'mail'

class Cormorant
  CACHE_DIRECTORY = 'cache/'

  def wake
    config = YAML.load_file('config.yaml')
    smtp = config['smtp']
    targets = config['targets']

    targets.each {|target|
      uri = target['uri']
      word = target['word']
      mail = target['mail']

      cache_file_path = CACHE_DIRECTORY + Digest::SHA1.hexdigest(uri + word)
      cache = read cache_file_path
      now = read_uri uri
      diff = Diffy::Diff.new(cache, now, :allow_empty_diff => true, :context => 0).to_s.force_encoding('utf-8')
      addition = extract_addition diff
      find = find_word(addition, word)

      if find
        mail = Mail.new do
          from    'cormorant'
          to      mail
          subject 'Cormorant caught ' + '"' + word + '"'
          body    uri + "\n\n" + find.gsub(/<\/?[^>]*>/, '')
        end
        mail.delivery_method :smtp, { address:   smtp['address'],
                                      port:      smtp['port'],
                                      domain:    smtp['domain'],
                                      user_name: smtp['username'],
                                      password:  smtp['password'] }
        mail.charset = 'utf-8'
        mail.deliver!
      end

      write(cache_file_path, now)
    }
  end

  def read(path)
    unless File.exists? path
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.touch path
    end
    File.read(path, :encoding => Encoding::UTF_8)
  end

  def write(path, string)
    open(path, 'w') {|file|
      file.write string
    }
  end

  def read_uri(uri)
    doc = Nokogiri::HTML(open(uri))
    encoding = doc.encoding
    html = open(uri).read
    unless encoding =~ /utf-8/i
      html = html.encode('utf-8', encoding, :invalid => :replace, :undef => :replace)
    end
    html
  end

  def extract_addition(diff)
    addition = String.new
    diff.each_line {|line|
      initial = line[0, 1]
      if initial == '+'
        addition += line[1, line.length]
      end
    }
    addition
  end

  def find_word(sentence, word)
    if sentence =~ /#{word}/i
      find = String.new
      sentence.each_line {|line|
        if line =~ /#{word}/i
          find += line
        end
      }
    end
    find
  end
end